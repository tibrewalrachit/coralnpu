import Sparkle
import CoralNPU.Parameters
import CoralNPU.Interfaces
import CoralNPU.Common.Library
import CoralNPU.BitVec

namespace CoralNPU.Scalar

open Sparkle.Core.Signal
open Sparkle.IR.Builder
open CoralNPU.BitVec
open CoralNPU.Library

-- BRU-specific interfaces
structure BranchTargetData where
  data : BitVec 32
instance : Inhabited BranchTargetData := ⟨{ data := 0 }⟩

structure BranchTakenData (p : Parameters) where
  value : BitVec p.programCounterBits
instance {p : Parameters} : Inhabited (BranchTakenData p) := ⟨{ value := 0 }⟩

/-- 
  Branch State 
  Uses declare_signal_state to group state variables corresponding to 'BranchState' in Chisel.
-/
structure BranchState where
  valid          : Bool
  fwd            : Bool
  op             : BruOp
  target         : BitVec 32
  originalTarget : BitVec 32
  linkValid      : Bool
  linkAddr       : BitVec 5
  linkData       : BitVec 32
  pcEx           : BitVec 32
  inst           : BitVec 32

def BranchState.default : BranchState :=
  { valid := false, fwd := false, op := BruOp.JAL, target := 0#32, originalTarget := 0#32,
    linkValid := false, linkAddr := 0#5, linkData := 0#32, pcEx := 0#32, inst := 0#32 }

instance : Inhabited BranchState := ⟨BranchState.default⟩

structure BruOut (p : Parameters) where
  takenValid    : Bool
  takenValue    : BitVec p.programCounterBits
  actuallyTaken : Bool
  realTarget    : BitVec p.programCounterBits
  pc            : BitVec p.programCounterBits
  rd            : Valid RegfileWriteData

/-- 
  BRU (Branch Resolution Unit) for CoralNPU.
  Calculates branch targets, evaluates branch conditions.
  We omit the CSR integration for the 'first' unit in this baseline version.
-/
def bru {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters)
    (req : Signal dom (Valid (BruCmd p)))
    (rs1_in : Signal dom RegfileReadData)
    (rs2_in : Signal dom RegfileReadData)
    (targetIn : Signal dom BranchTargetData)
    : Signal dom (BruOut p) :=

  let reqValid := req.map (·.valid)
  let reqBits  := req.map (·.bits)

  let pcDe  := reqBits.map (·.pc)
  let pc4De := (· + 4#32) <$> pcDe

  let stateLoop := Signal.loop fun (state : Signal dom BranchState) =>
    
    let isJalOrJalr := (· == BruOp.JAL) <$> (reqBits.map (·.op)) ||| (· == BruOp.JALR) <$> (reqBits.map (·.op))
    
    let linkValid := reqValid &&& ((· != 0#5) <$> (reqBits.map (·.link))) &&& isJalOrJalr

    -- Omit FaultManager for now, so op is directly from req
    let nextOp := reqBits.map (·.op)
    let nextFwd := reqValid &&& (reqBits.map (·.fwd))

    let nextLinkAddr := reqBits.map (·.link)
    let nextLinkData := pc4De
    let nextPcEx := pcDe
    let nextInst := reqBits.map (·.inst)
    let nextOriginalTarget := reqBits.map (·.target)

    let reqTarget := reqBits.map (·.target)
    let reqFwd := reqBits.map (·.fwd)
    let isJalr := (· == BruOp.JALR) <$> (reqBits.map (·.op))
    
    let jalrTarget := (fun t => t &&& 0xFFFFFFFE#32) <$> (targetIn.map (·.data))
    
    let nextTarget := Signal.cond [
      (reqFwd, pc4De),
      (isJalr, jalrTarget)
    ] reqTarget

    let stateRegValid := reqValid
    
    let nextValid_cond := Signal.mux stateRegValid (Signal.pure true) (BranchState.valid state)
    let nextFwd_cond := Signal.mux stateRegValid nextFwd (BranchState.fwd state)
    let nextOp_cond := Signal.mux stateRegValid nextOp (BranchState.op state)
    let nextTarget_cond := Signal.mux stateRegValid nextTarget (BranchState.target state)
    let nextOriginalTarget_cond := Signal.mux stateRegValid nextOriginalTarget (BranchState.originalTarget state)
    let nextLinkValid_cond := Signal.mux stateRegValid linkValid (BranchState.linkValid state)
    let nextLinkAddr_cond := Signal.mux stateRegValid nextLinkAddr (BranchState.linkAddr state)
    let nextLinkData_cond := Signal.mux stateRegValid nextLinkData (BranchState.linkData state)
    let nextPcEx_cond := Signal.mux stateRegValid (nextPcEx.map (·.extractLsb 31 0)) (BranchState.pcEx state)
    let nextInst_cond := Signal.mux stateRegValid nextInst (BranchState.inst state)

    Signal.register BranchState.default (
      (fun v f o t ot lv la ld pc i => (v, (f, (o, (t, (ot, (lv, (la, (ld, (pc, i)))))))))) 
      <$> nextValid_cond <*> nextFwd_cond <*> nextOp_cond <*> nextTarget_cond <*> nextOriginalTarget_cond
      <*> nextLinkValid_cond <*> nextLinkAddr_cond <*> nextLinkData_cond <*> nextPcEx_cond <*> nextInst_cond
    )

  let rs1 := rs1_in.map (·.data)
  let rs2 := rs2_in.map (·.data)

  let eq  := (· == ·) <$> rs1 <*> rs2
  let neq := ~~~eq
  let lt  := BitVec.slt <$> rs1 <*> rs2
  let ge  := ~~~lt
  let ltu := (· < ·) <$> rs1 <*> rs2
  let geu := ~~~ltu

  let op := BranchState.op stateLoop
  let fwdOut := BranchState.fwd stateLoop
  let validOut := BranchState.valid stateLoop

  let isTaken := Signal.cond [
    (op === BruOp.JAL,  Signal.pure true),
    (op === BruOp.JALR, Signal.pure true),
    (op === BruOp.BEQ,  eq),
    (op === BruOp.BNE,  neq),
    (op === BruOp.BLT,  lt),
    (op === BruOp.BGE,  ge),
    (op === BruOp.BLTU, ltu),
    (op === BruOp.BGEU, geu)
  ] (Signal.pure false)

  -- Taken valid is if the taken status differs from fwd
  let takenValidBase := Signal.cond [
    (op === BruOp.JAL,  ~(fwdOut)),
    (op === BruOp.JALR, ~(fwdOut)),
    (op === BruOp.BEQ,  (fun e f => e != f) <$> eq <*> fwdOut),
    (op === BruOp.BNE,  (fun n f => n != f) <$> neq <*> fwdOut),
    (op === BruOp.BLT,  (fun l f => l != f) <$> lt <*> fwdOut),
    (op === BruOp.BGE,  (fun g f => g != f) <$> ge <*> fwdOut),
    (op === BruOp.BLTU, (fun l f => l != f) <$> ltu <*> fwdOut),
    (op === BruOp.BGEU, (fun g f => g != f) <$> geu <*> fwdOut)
  ] (Signal.pure false)

  let takenValid := validOut &&& takenValidBase
  let actuallyTaken := validOut &&& isTaken

  let targetOut := BranchState.target stateLoop
  let originalTargetOut := BranchState.originalTarget stateLoop

  let jalrTarget2 := (fun t => t &&& 0xFFFFFFFE#32) <$> (targetIn.map (·.data))
  
  let realTarget := Signal.mux fwdOut 
    (Signal.mux (op === BruOp.JALR) jalrTarget2 originalTargetOut)
    targetOut

  let pcOut := BranchState.pcEx stateLoop

  let rdValid := validOut &&& (BranchState.linkValid stateLoop)
  let rdAddr := BranchState.linkAddr stateLoop
  let rdData := BranchState.linkData stateLoop

  let rdOut := (fun v a d => { valid := v, bits := { addr := a, data := d } : Valid RegfileWriteData }) <$> rdValid <*> rdAddr <*> rdData

  (fun tv val at rt p r => { takenValid := tv, takenValue := val, actuallyTaken := at, realTarget := rt, pc := p, rd := r : BruOut p })
    <$> takenValid <*> targetOut <*> actuallyTaken <*> realTarget <*> pcOut <*> rdOut

end CoralNPU.Scalar
