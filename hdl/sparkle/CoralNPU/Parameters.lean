import Sparkle

namespace CoralNPU

inductive MemoryRegionType where
  | IMEM
  | DMEM
  | Peripheral
  | External
  deriving Repr, BEq

structure MemoryRegion where
  memStart : Nat
  memSize : Nat
  memType : MemoryRegionType
  deriving Repr, BEq

def MemoryRegion.contains (region : MemoryRegion) (addr : Nat) : Bool :=
  addr >= region.memStart && addr < region.memStart + region.memSize

namespace MemoryRegions
  def default : List MemoryRegion := [
    { memStart := 0x0000000, memSize := 0x00002000, memType := MemoryRegionType.IMEM }, -- ITCM
    { memStart := 0x0010000, memSize := 0x00008000, memType := MemoryRegionType.DMEM }, -- DTCM
    { memStart := 0x0030000, memSize := 0x00001000, memType := MemoryRegionType.Peripheral } -- CSR
  ]

  def highmem (itcmSizeKBytes dtcmSizeKBytes : Nat) : List MemoryRegion := [
    { memStart := 0x00000000, memSize := itcmSizeKBytes * 1024, memType := MemoryRegionType.IMEM }, -- ITCM
    { memStart := 0x00100000, memSize := dtcmSizeKBytes * 1024, memType := MemoryRegionType.DMEM }, -- DTCM
    { memStart := 0x00200000, memSize := 0x00001000, memType := MemoryRegionType.Peripheral } -- CSR
  ]
end MemoryRegions

structure Parameters where
  m : List MemoryRegion := default
  hartId : Nat := 0

  -- Machine
  programCounterBits : Nat := 32
  instructionBits : Nat := 32
  instructionLanes : Nat := 4

  -- Features
  enableVerification : Bool := false
  enableRvv : Bool := false
  rvvVlen : Nat := 128
  
  -- Scalar Floating point
  enableFloat : Bool := false
  floatPulpDivsqrt : Nat := 0

  -- Retirement buffer
  floatRegfileBaseAddr : Nat := 32
  rvvRegfileBaseAddr : Nat := 64
  rvvRegCount : Nat := 32
  retirementBufferSize : Nat := 8

  -- Cache/Fetch
  enableFetchL0 : Bool := true
  fetchAddrBits : Nat := 32
  fetchL0Sets : Nat := 4
  fetchL0Ways : Nat := 2
  
  -- Base bus configurations
  fetchDataBits : Nat := 128
  lsuAddrBits : Nat := 32
  lsuDataBits : Nat := 32
  dbusSize : Nat := 2 -- log2Ceil(lsuDataBits / 8 + 1) -> 2 bits for max 4 bytes
  dbusExtSize : Nat := 4

  axi2AddrBits : Nat := 32
  axi2DataBits : Nat := 128

namespace Parameters
  -- Derived parameters
  def rvvVlenb (p : Parameters) : Nat := p.rvvVlen / 8
  def useRetirementBuffer (p : Parameters) : Bool := p.enableVerification
  
  def retirementBufferIdxWidth (p : Parameters) : Nat :=
    -- Simplified log2Ceil for (scalarRegCount + floatRegCount + rvvRegCount + 2)
    -- 32 + 0 + 32 + 2 = 66 -> requires 7 bits
    if p.enableFloat then 8 else 7
end Parameters

end CoralNPU
