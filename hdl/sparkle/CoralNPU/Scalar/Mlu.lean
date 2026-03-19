import Sparkle
import CoralNPU.Parameters
import CoralNPU.Interfaces
import CoralNPU.Common.Library
import CoralNPU.Common.Fifo

namespace CoralNPU.Scalar

open Sparkle.Core.Signal
open Sparkle.IR.Builder
open CoralNPU.BitVec
open CoralNPU.Library
open CoralNPU.Common

-- Internal structures for MLU pipeline stages
structure MluStage1 (p : Parameters) where
  rd : BitVec 5
  op : MluOp
  sel : BitVec p.instructionLanes

instance {p : Parameters} : Inhabited (MluStage1 p) := 
  ⟨{ rd := 0, op := MluOp.MUL, sel := 0 }⟩

structure MluStage2 (p : Parameters) where
  rd : BitVec 5
  op : MluOp
  prod : BitVec 66 -- Signed product

instance {p : Parameters} : Inhabited (MluStage2 p) := 
  ⟨{ rd := 0, op := MluOp.MUL, prod := 0 }⟩

/-- 
  MLU (Multiplier Unit) for CoralNPU.
  3-stage pipelined multiplier:
  Stage 1: Arbitrate + Select
  Stage 2: 33x33 bit signed multiplication
  Stage 3: Select product high/low
-/
def mlu {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters)
    (reqList : List (Signal dom (FifoIn MluCmd)))
    (rs1List : List (Signal dom RegfileReadData))
    (rs2List : List (Signal dom RegfileReadData))
    (rdReady : Signal dom Bool)
    : Signal dom (FifoOut RegfileWriteData) :=
  
  -- Create a prioritized "any valid" and the chosen command
  -- (Simple reduction since only one lane typically issues an MLU command per cycle)
  let anyValid1 := reqList.foldl (fun acc req => acc ||| req.map (·.inValid)) (Signal.pure false)
  
  -- Mux tree for the chosen command and the one-hot selection vector
  let chosenCmd := 
    (List.range p.instructionLanes).foldl (fun acc i => 
      let req := reqList.getD i (Signal.pure { inValid := false, inBits := default, outReady := false })
      Signal.mux (req.map (·.inValid)) (req.map (·.inBits)) acc
    ) (Signal.pure default)

  let chosenSel := 
    (List.range p.instructionLanes).foldl (fun acc i => 
      let req := reqList.getD i (Signal.pure { inValid := false, inBits := default, outReady := false })
      Signal.mux (req.map (·.inValid)) (Signal.pure (1#p.instructionLanes <<< i)) acc
    ) (Signal.pure 0#p.instructionLanes)

  let stage1Bits := (fun cmd sel => { rd := cmd.addr, op := cmd.op, sel := sel : MluStage1 p }) <$> chosenCmd <*> chosenSel

  -- Queue 1 (Output of Stage 1 to Stage 2)
  -- Uses the Fifo stub with capacity 1
  let q1In := (fun v b => { inValid := v, inBits := b, outReady := true : FifoIn (MluStage1 p) }) <$> anyValid1 <*> stage1Bits
  let q1Out := fifo { n := 1, passReady := true } q1In

  let valid2in := q1Out.map (·.outValid)
  let bits2in  := q1Out.map (·.outBits)
  let op2in    := bits2in.map (·.op)
  let addr2in  := bits2in.map (·.rd)
  let sel2in   := bits2in.map (·.sel)

  -- Read data multiplexing based on chosen lane
  let rs1 := (List.range p.instructionLanes).foldl (fun acc i =>
      let laneValid := (fun sel => (sel &&& (1#p.instructionLanes <<< i)) != 0#p.instructionLanes) <$> sel2in
      let rdData := (rs1List.getD i (Signal.pure default)).map (·.data)
      (fun a b => a ||| b) <$> acc <*> muxOR (valid2in &&& laneValid) rdData
    ) (Signal.pure 0#32)

  let rs2 := (List.range p.instructionLanes).foldl (fun acc i =>
      let laneValid := (fun sel => (sel &&& (1#p.instructionLanes <<< i)) != 0#p.instructionLanes) <$> sel2in
      let rdData := (rs2List.getD i (Signal.pure default)).map (·.data)
      (fun a b => a ||| b) <$> acc <*> muxOR (valid2in &&& laneValid) rdData
    ) (Signal.pure 0#32)

  -- Stage 2: 33x33 signed multiplication
  let rs2signed := (· == MluOp.MULH) <$> op2in
  let rs1signed := (· == MluOp.MULHSU) <$> op2in ||| rs2signed

  -- Sign extension logic (32 bits -> 33 bits)
  let rs1s := (fun s1 (r1 : BitVec 32) => 
      let msb := if s1 && r1.getMsb 31 then 1#1 else 0#1
      msb ++ r1
    ) <$> rs1signed <*> rs1

  let rs2s := (fun s2 (r2 : BitVec 32) => 
      let msb := if s2 && r2.getMsb 31 then 1#1 else 0#1
      msb ++ r2
    ) <$> rs2signed <*> rs2

  -- 33x33 bit signed multiplication gives 66 bits
  let prod := (fun a b => BitVec.ofInt 66 (a.toInt * b.toInt)) <$> rs1s <*> rs2s

  let stage2Bits := (fun rd op pr => { rd := rd, op := op, prod := pr : MluStage2 p }) <$> addr2in <*> op2in <*> prod

  -- Queue 2 (Output of Stage 2 to Stage 3)
  let q2In := (fun v b r => { inValid := v, inBits := b, outReady := r : FifoIn (MluStage2 p) }) <$> valid2in <*> stage2Bits <*> rdReady
  let q2Out := fifo { n := 1, passReady := true } q2In

  let valid3in := q2Out.map (·.outValid)
  let bits3in  := q2Out.map (·.outBits)
  let op3in    := bits3in.map (·.op)
  let prod3in  := bits3in.map (·.prod)

  -- Stage 3: Product extraction
  let mulData := Signal.mux ((· == MluOp.MUL) <$> op3in) 
      (prod3in.map (·.extractLsb 31 0))  -- MUL (low 32 bits)
      (prod3in.map (·.extractLsb 63 32)) -- MULH, MULHSU, MULHU (high 32 bits)

  let rdData := (fun a d => { valid := true, addr := a, data := d : RegfileWriteData }) <$> (bits3in.map (·.rd)) <*> mulData

  -- Return FifoOut interface
  (fun r v d => { inReady := r, outValid := v, outBits := d, count := if v then 1#32 else 0#32 : FifoOut RegfileWriteData })
    <$> (q1Out.map (·.inReady)) <*> valid3in <*> rdData

end CoralNPU.Scalar
