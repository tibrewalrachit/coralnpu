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

/-- 
  DVU FSM and Data State
  Uses declare_signal_state to group all registers needed for the iterative divider.
-/
structure DvuState where
  active   : Bool
  compute  : Bool
  addr1    : BitVec 5
  signed1  : Bool
  divide1  : Bool
  addr2    : BitVec 5
  signed2d : Bool
  signed2r : Bool
  divide2  : Bool
  count    : BitVec 6
  divide   : BitVec 32
  remain   : BitVec 32
  denom    : BitVec 32

def DvuState.default : DvuState :=
  { active := false, compute := false, addr1 := 0#5, signed1 := false, divide1 := false,
    addr2 := 0#5, signed2d := false, signed2r := false, divide2 := false,
    count := 0#6, divide := 0#32, remain := 0#32, denom := 0#32 }

instance : Inhabited DvuState := ⟨DvuState.default⟩

/-- 
  DVU (Divider Unit) for CoralNPU.
  Iterative divider, executes one bit per cycle.
  Implements DIV, DIVU, REM, REMU.
-/
def dvu {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters)
    (req : Signal dom (Valid DvuCmd))
    (reqReady : Signal dom Bool) -- Decoupled ready signal from outside
    (rs1_in : Signal dom RegfileReadData)
    (rs2_in : Signal dom RegfileReadData)
    (rdReady : Signal dom Bool)
    : Signal dom (Valid RegfileWriteData) × Signal dom Bool :=

  let rs1 := rs1_in.map (·.data)
  let rs2 := rs2_in.map (·.data)
  let reqValid := req.map (·.valid)
  let reqOp := req.map (·.bits.op)
  let reqAddr := req.map (·.bits.addr)

  let divByZero := (· == 0#32) <$> rs2

  -- Helper to do one division step
  let divideStep := fun (prvDivide prvRemain denom : BitVec 32) =>
    let shfRemain := (prvRemain.extractLsb 30 0) ++ prvDivide.extractLsb 31 31
    -- subtraction modeled with 33 bits to check borrow (MSB)
    let subOp := (signExt (w := 32) (n := 33) shfRemain) - (signExt (w := 32) (n := 33) denom)
    
    if !subOp.getLsb 32 then
      (prvDivide.extractLsb 30 0 ++ 1#1, subOp.extractLsb 31 0)
    else
      (prvDivide.extractLsb 30 0 ++ 0#1, shfRemain)

  let stateLoop := Signal.loop fun (state : Signal dom DvuState) =>
    let active := DvuState.active state
    let compute := DvuState.compute state
    let count := DvuState.count state
    
    let isCount5 := (·.getLsb 5) <$> count
    let reqFire := reqValid &&& reqReady
    
    -- Next active logic
    let nextActive := Signal.cond [
      (reqFire, Signal.pure true),
      (count === 30#6, Signal.pure false)
    ] active

    -- Next compute is just delayed active
    let nextCompute := active

    let isDivOrRem := (· == DvuOp.DIV) <$> reqOp ||| (· == DvuOp.REM) <$> reqOp
    let isDivOrDivU := (· == DvuOp.DIV) <$> reqOp ||| (· == DvuOp.DIVU) <$> reqOp

    let nextAddr1 := Signal.mux reqFire reqAddr (DvuState.addr1 state)
    let nextSigned1 := Signal.mux reqFire isDivOrRem (DvuState.signed1 state)
    let nextDivide1 := Signal.mux reqFire isDivOrDivU (DvuState.divide1 state)

    -- The "active && !compute" cycle (setup cycle)
    let setupCycle := active &&& (~~~compute)
    
    let rs1Signed31 := DvuState.signed1 state &&& (·.getLsb 31) <$> rs1
    let rs2Signed31 := DvuState.signed1 state &&& (·.getLsb 31) <$> rs2

    -- Different signs?
    let signsDiff := (fun s1 s2 => s1.getLsb 31 != s2.getLsb 31) <$> rs1 <*> rs2
    let nextSigned2d := DvuState.signed1 state &&& signsDiff &&& (~~~divByZero)
    let nextSigned2r := rs1Signed31

    -- Absolute values (2's complement negation if negative)
    let inp := Signal.mux rs1Signed31 (~~~rs1 + 1#32) rs1
    let denomSetup := Signal.mux rs2Signed31 (~~~rs2 + 1#32) rs2

    -- Count leading zeros variant (one less than priority encoding)
    let clz1 := (clz ·) <$> inp
    let clzVal := Signal.mux divByZero (Signal.pure 0#6) (clz1.map (·.extractLsb 5 0))

    let divideSetup := (· <<< ·.toNat) <$> inp <*> clzVal
    let remainSetup := Signal.pure 0#32
    let countSetup := clzVal

    -- The compute cycle (iterative step)
    let computeCycle := compute &&& ((· < 32#6) <$> count)
    
    let stepped := (fun d r dnm => divideStep d r dnm) <$> (DvuState.divide state) <*> (DvuState.remain state) <*> (DvuState.denom state)
    let divideStepOut := stepped.map (·.1)
    let remainStepOut := stepped.map (·.2)
    let countStepOut := (· + 1#6) <$> count

    -- The completion/output cycle
    let completeCycle := (fun c => (c &&& 32#6) != 0#6) <$> count
    let rdFire := completeCycle &&& rdReady
    let countOut := Signal.mux rdFire (Signal.pure 0#6) count

    -- Mux trees for register updates
    let nextAddr2 := Signal.mux setupCycle nextAddr1 (DvuState.addr2 state)
    let nSigned2d := Signal.mux setupCycle nextSigned2d (DvuState.signed2d state)
    let nSigned2r := Signal.mux setupCycle nextSigned2r (DvuState.signed2r state)
    let nDivide2  := Signal.mux setupCycle nextDivide1 (DvuState.divide2 state)

    let nextDenom := Signal.mux setupCycle denomSetup (DvuState.denom state)
    
    let nextDivide := Signal.cond [
      (setupCycle, divideSetup),
      (computeCycle, divideStepOut)
    ] (DvuState.divide state)

    let nextRemain := Signal.cond [
      (setupCycle, remainSetup),
      (computeCycle, remainStepOut)
    ] (DvuState.remain state)

    let nextCount := Signal.cond [
      (setupCycle, countSetup),
      (computeCycle, countStepOut),
      (rdFire, Signal.pure 0#6)
    ] count

    -- Update state
    Signal.register DvuState.default (
      (fun a c a1 s1 d1 a2 s2d s2r d2 cnt div rem dnm => 
        (a, (c, (a1, (s1, (d1, (a2, (s2d, (s2r, (d2, (cnt, (div, (rem, dnm))))))))))))
      ) <$> nextActive <*> nextCompute <*> nextAddr1 <*> nextSigned1 <*> nextDivide1 
        <*> nextAddr2 <*> nSigned2d <*> nSigned2r <*> nDivide2 
        <*> nextCount <*> nextDivide <*> nextRemain <*> nextDenom
    )

  -- Ready signal output to req
  let active := DvuState.active stateLoop
  let compute := DvuState.compute stateLoop
  let count := DvuState.count stateLoop
  let outReqReady := (~~~active) &&& (~~~compute) &&& (~~~((fun c => (c &&& 32#6) != 0#6) <$> count))

  -- Output results
  let divRes := Signal.mux (DvuState.signed2d stateLoop) (~~~(DvuState.divide stateLoop) + 1#32) (DvuState.divide stateLoop)
  let remRes := Signal.mux (DvuState.signed2r stateLoop) (~~~(DvuState.remain stateLoop) + 1#32) (DvuState.remain stateLoop)
  
  let validOut := (fun c => (c &&& 32#6) != 0#6) <$> count
  let addrOut := DvuState.addr2 stateLoop
  let dataOut := Signal.mux (DvuState.divide2 stateLoop) divRes remRes

  let rdOut := (fun v a d => { valid := v, bits := { addr := a, data := d } : Valid RegfileWriteData }) <$> validOut <*> addrOut <*> dataOut

  (rdOut, outReqReady)

end CoralNPU.Scalar
