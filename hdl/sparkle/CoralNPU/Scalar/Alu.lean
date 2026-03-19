import Sparkle
import CoralNPU.Parameters
import CoralNPU.Interfaces
import CoralNPU.Common.Library

namespace CoralNPU.Scalar

open Sparkle.Core.Signal
open Sparkle.IR.Builder
open CoralNPU.BitVec
open CoralNPU.Library

/-- 
  ALU (Arithmetic Logic Unit) for CoralNPU.
  One-cycle latency registered pipelined unit for scalar operations.
-/
def alu {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters)
    (req : Signal dom (Valid AluCmd))
    (rs1_in : Signal dom RegfileReadData)
    (rs2_in : Signal dom RegfileReadData)
    : Signal dom (Valid RegfileWriteData) :=

  let reqValid := req.map (·.valid)
  let reqAddr  := req.map (·.bits.addr)
  let reqOp    := req.map (·.bits.op)

  -- Pipeline registers for valid, addr, and op (update only on valid req)
  let validReg := Signal.register false reqValid
  let addrReg  := Signal.registerWithEnable 0#5 reqValid reqAddr
  let opReg    := Signal.registerWithEnable AluOp.ADD reqValid reqOp

  -- Inputs are combinational from rs1/rs2, read in the execute cycle
  let rs1 := rs1_in.map (·.data)
  let rs2 := rs2_in.map (·.data)
  let shamt := rs2.map (fun v => v.extractLsb 4 0)

  -- Basic comparisons
  let isSlt  := BitVec.slt <$> rs1 <*> rs2
  let isSltu := (· < ·) <$> rs1 <*> rs2

  -- Helper operations
  let sllRes := (· <<< ·.toNat) <$> rs1 <*> shamt
  let srlRes := (· >>> ·.toNat) <$> rs1 <*> shamt
  let sraRes := (fun x y => BitVec.sshiftRight x y.toNat) <$> rs1 <*> shamt
  
  -- ZBB helpers
  let minRes  := minS rs1 rs2
  let minuRes := minU rs1 rs2
  let maxRes  := maxS rs1 rs2
  let maxuRes := maxU rs1 rs2

  let sextbRes := (signExt (w := 8) (n := 32)) <$> (rs1.map (·.extractLsb 7 0))
  let sexthRes := (signExt (w := 16) (n := 32)) <$> (rs1.map (·.extractLsb 15 0))
  let zexthRes := (zeroExt (w := 16) (n := 32)) <$> (rs1.map (·.extractLsb 15 0))
  
  let rolRes := (·.rotateLeft ·.toNat) <$> rs1 <*> shamt
  let rorRes := (·.rotateRight ·.toNat) <$> rs1 <*> shamt

  -- ORCB: OR-Combine bytes. Replace each byte with 0xFF if non-zero, else 0x00.
  let orcbRes := rs1.map fun x =>
    let b0 := if x.extractLsb 7 0 != 0 then 0xFF#8 else 0#8
    let b1 := if x.extractLsb 15 8 != 0 then 0xFF#8 else 0#8
    let b2 := if x.extractLsb 23 16 != 0 then 0xFF#8 else 0#8
    let b3 := if x.extractLsb 31 24 != 0 then 0xFF#8 else 0#8
    b3 ++ b2 ++ b1 ++ b0

  -- REV8: Byte reverse
  let rev8Res := rs1.map fun x =>
    x.extractLsb 7 0 ++ x.extractLsb 15 8 ++ x.extractLsb 23 16 ++ x.extractLsb 31 24

  let dataOut := Signal.cond [
    (opReg === AluOp.ADD,  (· + ·) <$> rs1 <*> rs2),
    (opReg === AluOp.SUB,  (· - ·) <$> rs1 <*> rs2),
    (opReg === AluOp.SLT,  isSlt.map fun b => if b then 1#32 else 0#32),
    (opReg === AluOp.SLTU, isSltu.map fun b => if b then 1#32 else 0#32),
    (opReg === AluOp.XOR,  (· ^^^ ·) <$> rs1 <*> rs2),
    (opReg === AluOp.OR,   (· ||| ·) <$> rs1 <*> rs2),
    (opReg === AluOp.AND,  (· &&& ·) <$> rs1 <*> rs2),
    (opReg === AluOp.SLL,  sllRes),
    (opReg === AluOp.SRL,  srlRes),
    (opReg === AluOp.SRA,  sraRes),
    (opReg === AluOp.LUI,  rs2),
    
    -- ZBB Extensions
    (opReg === AluOp.ANDN, (· &&& ·) <$> rs1 <*> (~~~rs2)),
    (opReg === AluOp.ORN,  (· ||| ·) <$> rs1 <*> (~~~rs2)),
    (opReg === AluOp.XNOR, ~~~((· ^^^ ·) <$> rs1 <*> rs2)),
    (opReg === AluOp.CLZ,  (clz ·) <$> rs1),
    (opReg === AluOp.CTZ,  (ctz ·) <$> rs1),
    (opReg === AluOp.CPOP, (cpop ·) <$> rs1),
    (opReg === AluOp.MAX,  maxRes),
    (opReg === AluOp.MAXU, maxuRes),
    (opReg === AluOp.MIN,  minRes),
    (opReg === AluOp.MINU, minuRes),
    (opReg === AluOp.SEXTB, sextbRes),
    (opReg === AluOp.SEXTH, sexthRes),
    (opReg === AluOp.ROL,  rolRes),
    (opReg === AluOp.ROR,  rorRes),
    (opReg === AluOp.ORCB, orcbRes),
    (opReg === AluOp.REV8, rev8Res),
    (opReg === AluOp.ZEXTH, zexthRes)
  ] ((· + ·) <$> rs1 <*> rs2) -- default ADD

  (fun v a d => { valid := v, bits := { addr := a, data := d } }) <$> validReg <*> addrReg <*> dataOut

end CoralNPU.Scalar
