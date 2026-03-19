import Sparkle
import CoralNPU.Parameters

namespace CoralNPU

open Sparkle.Core.Signal

-- ============================================================================
-- Enums
-- ============================================================================

inductive AluOp where
  | ADD
  | SUB
  | SLT
  | SLTU
  | XOR
  | OR
  | AND
  | SLL
  | SRL
  | SRA
  | LUI
  | ANDN
  | ORN
  | XNOR
  | CLZ
  | CTZ
  | CPOP
  | MAX
  | MAXU
  | MIN
  | MINU
  | SEXTB
  | SEXTH
  | ROL
  | ROR
  | ORCB
  | REV8
  | ZEXTH
  deriving Repr, BEq

-- Let AluOp have an Inhabited instance so it can be used in Signals
instance : Inhabited AluOp := ⟨AluOp.ADD⟩

inductive MluOp where
  | MUL
  | MULH
  | MULHSU
  | MULHU
  deriving Repr, BEq

instance : Inhabited MluOp := ⟨MluOp.MUL⟩

inductive DvuOp where
  | DIV
  | DIVU
  | REM
  | REMU
  deriving Repr, BEq

instance : Inhabited DvuOp := ⟨DvuOp.DIV⟩

inductive BruOp where
  | JAL
  | JALR
  | BEQ
  | BNE
  | BLT
  | BGE
  | BLTU
  | BGEU
  deriving Repr, BEq

instance : Inhabited BruOp := ⟨BruOp.BEQ⟩

inductive CsrOp where
  | CSRRW
  | CSRRS
  | CSRRC
  deriving Repr, BEq

instance : Inhabited CsrOp := ⟨CsrOp.CSRRW⟩

-- ============================================================================
-- Common Bundles (Valid and Decoupled)
-- ============================================================================

-- A generic Valid interface is represented in Sparkle as a pair of (Bool, α)
-- where the first element is the 'valid' bit.

/-- Valid interface structure for use in domains -/
structure Valid (α : Type) where
  valid : Bool
  bits : α
  deriving Repr

-- Ensure we can create Signals out of Valid bundles
instance [Inhabited α] : Inhabited (Valid α) := ⟨{ valid := false, bits := default }⟩

-- Decoupled (Ready/Valid) is typically bidirectional. In a functional HDL,
-- this is split into an Output parameter and an Input parameter for a module.

-- ============================================================================
-- Specific Interface Bundles
-- ============================================================================

structure FaultInfo (p : Parameters) where
  write : Bool
  addr : BitVec p.programCounterBits
  epc : BitVec p.programCounterBits

instance {p : Parameters} : Inhabited (FaultInfo p) := 
  ⟨{ write := false, addr := 0, epc := 0 }⟩

-- IBus
structure IBusReq (p : Parameters) where
  valid : Bool
  addr : BitVec p.fetchAddrBits

structure IBusResp (p : Parameters) where
  ready : Bool
  rdata : BitVec p.fetchDataBits
  fault : Valid (FaultInfo p)

-- DBus (Simplified without banking logic for now)
structure DBusReq (p : Parameters) where
  valid : Bool
  write : Bool
  pc : BitVec 32
  addr : BitVec p.lsuAddrBits
  adrx : BitVec p.lsuAddrBits
  size : BitVec p.dbusSize
  wdata : BitVec p.lsuDataBits
  wmask : BitVec (p.lsuDataBits / 8)

structure DBusResp (p : Parameters) where
  ready : Bool
  rdata : BitVec p.lsuDataBits

-- Register File IOs
structure RegfileReadData where
  valid : Bool
  data : BitVec 32

instance : Inhabited RegfileReadData := ⟨{ valid := false, data := 0 }⟩

structure RegfileWriteData where
  valid : Bool
  addr : BitVec 5
  data : BitVec 32

instance : Inhabited RegfileWriteData := ⟨{ valid := false, addr := 0, data := 0 }⟩

-- ALU / Exec IOs
structure AluCmd where
  addr : BitVec 5
  op : AluOp

instance : Inhabited AluCmd := ⟨{ addr := 0, op := default }⟩

structure MluCmd where
  addr : BitVec 5
  op : MluOp

instance : Inhabited MluCmd := ⟨{ addr := 0, op := default }⟩

structure DvuCmd where
  addr : BitVec 5
  op : DvuOp

instance : Inhabited DvuCmd := ⟨{ addr := 0, op := default }⟩

structure BruCmd (p : Parameters) where
  fwd : Bool
  op : BruOp
  pc : BitVec p.programCounterBits
  target : BitVec p.programCounterBits
  link : BitVec 5
  inst : BitVec 32

instance {p : Parameters} : Inhabited (BruCmd p) := ⟨{ fwd := false, op := default, pc := 0, target := 0, link := 0, inst := 0 }⟩

end CoralNPU
