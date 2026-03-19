import Sparkle
import CoralNPU.Parameters
import CoralNPU.Interfaces
import CoralNPU.Common.Library
import CoralNPU.Common.Fifo
import CoralNPU.Scalar.Alu
import CoralNPU.Scalar.Mlu
import CoralNPU.Scalar.Dvu
import CoralNPU.Scalar.Bru
import CoralNPU.Scalar.Regfile

namespace CoralNPU.Scalar

open Sparkle.Core.Signal
open Sparkle.IR.Builder
open CoralNPU.BitVec
open CoralNPU.Library

-- Stubs for modules defined later in Phase 3
structure FetchOut (p : Parameters) where
  inst : List (Valid (FetchInstruction p))
  pc : BitVec p.fetchAddrBits
  -- other fields omitted for baseline stub

structure DecodeOut (p : Parameters) where
  aluSeq : List (Valid AluCmd)
  bruSeq : List (Valid (BruCmd p))
  mluSeq : List (FifoIn MluCmd)
  dvuReq : Valid DvuCmd
  -- regfile controls
  rs1Read : List RegfileReadAddr
  rs2Read : List RegfileReadAddr
  rs1Set  : List RegfileReadSet
  rs2Set  : List RegfileReadSet
  rdMark  : List RegfileWriteData
  busRead : List RegfileBusAddr

def fetchStub {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters) : Signal dom (FetchOut p) :=
  Signal.pure { inst := [], pc := 0, aluSeq := [], bruSeq := [], mluSeq := [], dvuReq := { valid := false, bits := default }, rs1Read := [], rs2Read := [], rs1Set := [], rs2Set := [], rdMark := [], busRead := [] }

def decodeStub {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters) (insts : Signal dom (List (Valid (FetchInstruction p)))) : Signal dom (DecodeOut p) :=
  Signal.pure { aluSeq := [], bruSeq := [], mluSeq := [], dvuReq := { valid := false, bits := default }, rs1Read := [], rs2Read := [], rs1Set := [], rs2Set := [], rdMark := [], busRead := [] }

/-- 
  SCore (Scalar Core) for CoralNPU.
  Top level structural wiring of execution units.
-/
def score {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters) :=
  
  -- Use IR Builder to instantiate modules and tie them together
  runModule do

    -- 1. Create Stubs for Fetch and Decode
    -- In a real Sparkle composition we might just pass recursive signals, but 
    -- IR builder lets us define them cleanly.
    let fetchInst ← makeWire (List (Valid (FetchInstruction p)))
    let fetchPc ← makeWire (BitVec p.fetchAddrBits)

    let decAluSeq ← makeWire (List (Valid AluCmd))
    let decBruSeq ← makeWire (List (Valid (BruCmd p)))
    let decMluSeq ← makeWire (List (FifoIn MluCmd))
    let decDvuReq ← makeWire (Valid DvuCmd)
    
    let decRs1Read ← makeWire (List RegfileReadAddr)
    let decRs2Read ← makeWire (List RegfileReadAddr)
    let decRs1Set  ← makeWire (List RegfileReadSet)
    let decRs2Set  ← makeWire (List RegfileReadSet)
    let decRdMark  ← makeWire (List RegfileWriteData)
    let decBusRead ← makeWire (List RegfileBusAddr)

    -- 2. Regfile Inputs
    let regfileInp ← makeWire (RegfileIn p)
    
    -- We need to collect writes from ALU, BRU, MLU, DVU, LSU, CSR
    -- Length = p.instructionLanes (ALU/BRU) + 2 (MLU/DVU + LSU)
    let writeDataList ← makeWire (List (Valid RegfileWriteData))
    let writeMaskList ← makeWire (List Bool)

    emitAssign regfileInp <| (fun rs1r rs2r rs1s rs2s rdm bmr wdl wml => 
        { readAddr := rs1r ++ rs2r
        , readSet := rs1s ++ rs2s
        , writeAddr := rdm
        , busAddr := bmr
        , debugBdIdx := 0#5
        , debugWriteValid := false
        , writeData := wdl
        , writeMask := wml : RegfileIn p }
      ) <$> decRs1Read <*> decRs2Read <*> decRs1Set <*> decRs2Set <*> decRdMark <*> decBusRead <*> writeDataList <*> writeMaskList
    
    -- Instantiate Regfile
    let rfOut := regfile p regfileInp

    -- 3. Execution Units

    -- ALU
    let aluOuts ← (List.range p.instructionLanes).mapM fun i => do
      let req := (·.get! i) <$> decAluSeq
      let rs1 := (·.get! (2*i)) <$> (rfOut.map (·.readData))
      let rs2 := (·.get! (2*i + 1)) <$> (rfOut.map (·.readData))
      pure (alu p req rs1 rs2)

    -- BRU
    let bruOuts ← (List.range p.instructionLanes).mapM fun i => do
      let req := (·.get! i) <$> decBruSeq
      let rs1 := (·.get! (2*i)) <$> (rfOut.map (·.readData))
      let rs2 := (·.get! (2*i + 1)) <$> (rfOut.map (·.readData))
      let tgt := (·.get! i) <$> (rfOut.map (·.target))
      pure (bru p req rs1 rs2 tgt)

    -- MLU
    let mluReqList := (List.range p.instructionLanes).map fun i => (·.get! i) <$> decMluSeq
    let mluRs1List := (List.range p.instructionLanes).map fun i => (·.get! (2*i)) <$> (rfOut.map (·.readData))
    let mluRs2List := (List.range p.instructionLanes).map fun i => (·.get! (2*i + 1)) <$> (rfOut.map (·.readData))
    let mluOut := mlu p mluReqList mluRs1List mluRs2List (Signal.pure true)

    -- DVU
    let dvuRs1 := (·.get! 0) <$> (rfOut.map (·.readData))
    let dvuRs2 := (·.get! 1) <$> (rfOut.map (·.readData))
    let dvuRes := dvu p decDvuReq (Signal.pure true) dvuRs1 dvuRs2 (Signal.pure true)
    let dvuOut := dvuRes.map (·.1)
    let dvuReady := dvuRes.map (·.2)

    -- 4. Writeback Arbitration

    -- Lane writes (ALU / BRU / CSR)
    let laneWrites := (List.range p.instructionLanes).map fun i =>
      let aOut := aluOuts.get! i
      let bOut := (·.rd) <$> (bruOuts.get! i)
      -- Merge valid writes (only one should be valid per lane by design)
      (fun a b => 
        if a.valid then a else if b.valid then b else { valid := false, bits := default }
      ) <$> aOut <*> bOut

    -- Multi-cycle write (MLU / DVU arbiter)
    -- Simplest arbitration: DVU has priority over MLU if both finish same cycle
    let mcWrite := (fun d m =>
      if d.valid then d else if m.outValid then { valid := true, bits := m.outBits } else { valid := false, bits := default }
    ) <$> dvuOut <*> mluOut

    -- LSU write (stubbed)
    let lsuWrite := Signal.pure { valid := false, bits := default : Valid RegfileWriteData }

    -- Combine into writeDataList
    let combinedWrites := laneWrites ++ [mcWrite, lsuWrite]
    
    emitAssign writeDataList <| combinedWrites.foldr (fun s acc => (List.cons · ·) <$> s <*> acc) (Signal.pure [])

    -- Mask generation (e.g. from branch taken)
    -- If a branch is taken, mask all writes in its shadow
    let branchTakenFlags := bruOuts.map (fun b => b.map (·.takenValid))
    let writeMasks := (List.range p.instructionLanes).map fun i =>
      let flag := branchTakenFlags.get! i
      -- scan right: if any later instruction branched, mask this one
      -- simplified for now
      flag

    let combinedMasks := writeMasks ++ [Signal.pure false, Signal.pure false] -- MLU/DVU/LSU unmasked
    emitAssign writeMaskList <| combinedMasks.foldr (fun s acc => (List.cons · ·) <$> s <*> acc) (Signal.pure [])

    -- Just returning a dummy boolean signaling core activity for now
    pure ((·.getLsb 0) <$> fetchPc)

end CoralNPU.Scalar
