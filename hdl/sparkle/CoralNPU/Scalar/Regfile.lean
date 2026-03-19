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

structure RegfileReadAddr where
  valid : Bool
  addr : BitVec 5
instance : Inhabited RegfileReadAddr := ⟨{ valid := false, addr := 0 }⟩

structure RegfileReadSet where
  valid : Bool
  value : BitVec 32
instance : Inhabited RegfileReadSet := ⟨{ valid := false, value := 0 }⟩

structure RegfileBusAddr where
  valid : Bool
  bypass : Bool
  immen : Bool
  immed : BitVec 32
instance : Inhabited RegfileBusAddr := ⟨{ valid := false, bypass := false, immen := false, immed := 0 }⟩

structure RegfileBranchTarget where
  data : BitVec 32
instance : Inhabited RegfileBranchTarget := ⟨{ data := 0 }⟩

structure RegfileLinkPort where
  valid : Bool
  value : BitVec 32
instance : Inhabited RegfileLinkPort := ⟨{ valid := false, value := 0 }⟩

structure RegfileBusPort (p : Parameters) where
  addr : List (BitVec 32) -- length p.instructionLanes
  data : List (BitVec 32) -- length p.instructionLanes

structure ScoreboardStatus where
  regd : BitVec 32
  comb : BitVec 32
instance : Inhabited ScoreboardStatus := ⟨{ regd := 0, comb := 0 }⟩

-- Inputs
structure RegfileIn (p : Parameters) where
  readAddr : List RegfileReadAddr    -- length: p.instructionLanes * 2
  readSet  : List RegfileReadSet     -- length: p.instructionLanes * 2
  writeAddr : List RegfileWriteData  -- length: p.instructionLanes (we use WriteData but ignore data part here to match writeAddr)
  busAddr  : List RegfileBusAddr     -- length: p.instructionLanes
  debugBdIdx : BitVec 5
  debugWriteValid : Bool
  writeData : List (Valid RegfileWriteData) -- length: p.instructionLanes + 2
  writeMask : List Bool                     -- length: p.instructionLanes + 2

-- Outputs
structure RegfileOut (p : Parameters) where
  readData : List RegfileReadData         -- length: p.instructionLanes * 2
  target : List RegfileBranchTarget       -- length: p.instructionLanes
  linkPort : RegfileLinkPort
  busPort : RegfileBusPort p
  debugData : BitVec 32
  scoreboard : ScoreboardStatus

/-- 
  32-entry Scoreboarded Register File.
  Uses Sparkle IR Builder to instantiate registers and manage multi-port arbitration.
-/
def regfile {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters)
    (inputs : Signal dom (RegfileIn p)) : Signal dom (RegfileOut p) :=
  
  -- The Chisel code uses a dense mutable array of 32 elements.
  -- In Sparkle IR Builder, we use emitRegister loop.
  runModule do

    let inReadAddr ← makeWire (List RegfileReadAddr)
    let inReadSet ← makeWire (List RegfileReadSet)
    let inWriteAddr ← makeWire (List RegfileWriteData)
    let inBusAddr ← makeWire (List RegfileBusAddr)
    let inDebugBdIdx ← makeWire (BitVec 5)
    let inDebugWriteValid ← makeWire Bool
    let inWriteData ← makeWire (List (Valid RegfileWriteData))
    let inWriteMask ← makeWire (List Bool)

    emitAssign inReadAddr (inputs.map (·.readAddr))
    emitAssign inReadSet (inputs.map (·.readSet))
    emitAssign inWriteAddr (inputs.map (·.writeAddr))
    emitAssign inBusAddr (inputs.map (·.busAddr))
    emitAssign inDebugBdIdx (inputs.map (·.debugBdIdx))
    emitAssign inDebugWriteValid (inputs.map (·.debugWriteValid))
    emitAssign inWriteData (inputs.map (·.writeData))
    emitAssign inWriteMask (inputs.map (·.writeMask))

    -- 32 Registers
    let regs ← (List.range 32).mapM fun _ => emitRegister 0#32
    
    -- Scoreboard
    let scoreboardReg ← emitRegister 0#32

    -- Scoreboard logic
    -- scoreboard_set = reduce OR of one-hot write Addrs
    let sbSetList := (List.range p.instructionLanes).map fun i =>
      let wa := (·.get! i) <$> inWriteAddr
      let isValid := wa.map (·.valid)
      let addr := wa.map (·.addr)
      let oh := (uintToOH 32 addr)
      muxOR isValid oh
    let scoreboardSet := (sbSetList.foldl (fun acc s => (· ||| ·) <$> acc <*> s) (Signal.pure 0#32))

    -- scoreboard_clr0 = reduce OR of one-hot writeData addrs
    let sbClrList := (List.range (p.instructionLanes + 2)).map fun i =>
      let wd := (·.get! i) <$> inWriteData
      let isValid := wd.map (·.valid)
      let addr := wd.map (·.bits.addr)
      let oh := (uintToOH 32 addr)
      muxOR isValid oh
    let scoreboardClr0 := (sbClrList.foldl (fun acc s => (· ||| ·) <$> acc <*> s) (Signal.pure 0#32))

    -- Clear LSB 0 (x0 is always 0, never scoreboards)
    let scoreboardClr := scoreboardClr0.map (fun v => v.extractLsb 31 1 ++ 0#1)

    -- Update scoreboard
    let nextScoreboard := (fun sb curSet curClr =>
        let masked := sb &&& (~~~curClr)
        let unmasked := masked ||| curSet
        unmasked.extractLsb 31 1 ++ 0#1
      ) <$> scoreboardReg <*> scoreboardSet <*> scoreboardClr

    let updateCond := (fun s c => s != 0#32 || c != 0#32) <$> scoreboardSet <*> scoreboardClr
    let finalNextSb := Signal.mux updateCond nextScoreboard scoreboardReg
    emitAssign scoreboardReg finalNextSb

    let sbStatusRegd := scoreboardReg
    let sbStatusComb := (· &&& ~~~·) <$> scoreboardReg <*> scoreboardClr

    -- Read data array
    let readDataReadyRegs ← (List.range (p.instructionLanes * 2)).mapM fun _ => emitRegister false
    let readDataBitsRegs ← (List.range (p.instructionLanes * 2)).mapM fun _ => emitRegister 0#32

    -- One hot write ports
    -- writeValid(i) = OR(valid_j & addr_j == i & !mask_j)
    -- writeData(i) = OR(data_j) where valid
    -- Optimization: reg 0 is never written, constant 0
    emitAssign (regs.get! 0) (Signal.pure 0#32)

    let writeEnables ← (List.range 32).mapM fun i => makeWire Bool
    let writeDatas ← (List.range 32).mapM fun i => makeWire (BitVec 32)
    
    emitAssign (writeEnables.get! 0) (Signal.pure true)
    emitAssign (writeDatas.get! 0) (Signal.pure 0#32)

    for i in [1:32] do
      let wvList := (List.range (p.instructionLanes + 2)).map fun j =>
        let wd := (·.get! j) <$> inWriteData
        let wm := (·.get! j) <$> inWriteMask
        let valid := wd.map (·.valid)
        let addr := wd.map (·.bits.addr)
        let data := wd.map (·.bits.data)
        
        let addrMatch := (· == BitVec.ofNat 5 i) <$> addr
        let isWriteValid := valid &&& addrMatch &&& (~~~wm)
        (isWriteValid, muxOR isWriteValid data)
        
      let anyValid := wvList.foldl (fun acc (v, d) => (· ||| ·) <$> acc <*> v) (Signal.pure false)
      let combinedData := wvList.foldl (fun acc (v, d) => (· ||| ·) <$> acc <*> d) (Signal.pure 0#32)
      
      emitAssign (writeEnables.get! i) anyValid
      emitAssign (writeDatas.get! i) combinedData

      -- If write enabled, assign to reg
      let nextReg := Signal.mux anyValid combinedData (regs.get! i)
      emitAssign (regs.get! i) nextReg

    -- Read ports with write forwarding
    let rwdata ← (List.range (p.instructionLanes * 2)).mapM fun i => do
      let ra := (·.get! i) <$> inReadAddr
      let idx := ra.map (·.addr)
      
      -- We must build a dense mux tree since lists can't be indexed by Signals in pure Lean easily without a fold.
      let writeHit := (List.range 32).foldl (fun acc r =>
          let isHit := (· == BitVec.ofNat 5 r) <$> idx
          Signal.mux isHit (writeEnables.get! r) acc
        ) (Signal.pure false)

      let rDataTree := (List.range 32).foldl (fun acc r =>
          let isHit := (· == BitVec.ofNat 5 r) <$> idx
          Signal.mux isHit (regs.get! r) acc
        ) (Signal.pure 0#32)

      let wDataTree := (List.range 32).foldl (fun acc r =>
          let isHit := (· == BitVec.ofNat 5 r) <$> idx
          Signal.mux isHit (writeDatas.get! r) acc
        ) (Signal.pure 0#32)

      let fwdData := Signal.mux writeHit wDataTree rDataTree
      pure (rDataTree, fwdData)

    let rdata := rwdata.map (·.1)
    let rwdata_fwd := rwdata.map (·.2)

    let nxtReadDataBits ← (List.range (p.instructionLanes * 2)).mapM fun i => makeWire (BitVec 32)

    for i in [0:p.instructionLanes * 2] do
      let rs := (·.get! i) <$> inReadSet
      let ra := (·.get! i) <$> inReadAddr
      
      let nxtBits := Signal.mux (rs.map (·.valid)) (rs.map (·.value)) (rwdata_fwd.get! i)
      emitAssign (nxtReadDataBits.get! i) nxtBits

      let rdReady := (ra.map (·.valid)) ||| (rs.map (·.valid))
      emitAssign (readDataReadyRegs.get! i) rdReady
      
      let rdBitsNext := Signal.cond [
        (rs.map (·.valid), rs.map (·.value)),
        (ra.map (·.valid), rwdata_fwd.get! i)
      ] (readDataBitsRegs.get! i)
      
      emitAssign (readDataBitsRegs.get! i) rdBitsNext

    -- Bus port priority encoded address
    let busAddrs ← (List.range p.instructionLanes).mapM fun i => makeWire (BitVec 32)
    for i in [0:p.instructionLanes] do
      let ba := (·.get! i) <$> inBusAddr
      let bypass := ba.map (·.bypass)
      let immen := ba.map (·.immen)
      let immed := ba.map (·.immed)
      let r2i := rwdata_fwd.get! (2*i)
      let rd2i := rdata.get! (2*i)

      let baVal := Signal.cond [
        (bypass, r2i),
        (immen, (· + ·) <$> rd2i <*> immed)
      ] rd2i
      emitAssign (busAddrs.get! i) baVal

    -- Pack outputs
    let outDebugData := (List.range 32).foldl (fun acc r =>
        let isHit := (· == BitVec.ofNat 5 r) <$> inDebugBdIdx
        Signal.mux isHit (regs.get! r) acc
      ) (Signal.pure 0#32)
      
    let outLinkPortValid := (·.getLsb 1 == false) <$> scoreboardReg
    let outLinkPortValue := regs.get! 1

    -- Aggregate into structs utilizing applicative lifting...
    -- (Omitted the massive nested apply for brevity, building a signal constructor instead)
    
    let out ← makeWire (RegfileOut p)
    
    emitAssign out <| (fun
        rdRD rdRB (ba : List (BitVec 32)) nrdb
        dbd sb_r sb_c lp_v lp_vlu =>
        
        let readDataOut := List.zipWith (fun v d => { valid := v, data := d : RegfileReadData }) rdRD rdRB
        
        let busPortData := (List.range p.instructionLanes).map fun i => nrdb.get! (2*i + 1)
        let busPortOut := { addr := ba, data := busPortData : RegfileBusPort p }
        
        let targetOut := ba.map fun ad => { data := ad : RegfileBranchTarget }
        
        let linkPortOut := { valid := lp_v, value := lp_vlu : RegfileLinkPort }
        
        let sbOut := { regd := sb_r, comb := sb_c : ScoreboardStatus }
        
        { readData := readDataOut
        , target := targetOut
        , linkPort := linkPortOut
        , busPort := busPortOut
        , debugData := dbd
        , scoreboard := sbOut : RegfileOut p }
      ) <$> (Signal.seq readDataReadyRegs) <*> (Signal.seq readDataBitsRegs) <*> (Signal.seq busAddrs) <*> (Signal.seq nxtReadDataBits)
        <*> outDebugData <*> sbStatusRegd <*> sbStatusComb <*> outLinkPortValid <*> outLinkPortValue

    pure out

end CoralNPU.Scalar
