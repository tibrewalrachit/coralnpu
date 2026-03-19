import Sparkle

namespace CoralNPU

-- ============================================================================
-- BitVec Extensions (Pure Lean functions for use in Signals)
-- ============================================================================

namespace BitVec

/-- Create a mask with `n` LSBs set to 1 -/
def mask (n width : Nat) : BitVec width :=
  (1#width <<< n) - 1#width

/-- Sign extend a BitVec `v` of width `w` to width `n` (where n ≥ w) -/
def signExt {w n : Nat} (v : BitVec w) : BitVec n :=
  BitVec.ofInt n v.toInt

/-- Zero extend a BitVec `v` of width `w` to width `n` (where n ≥ w) -/
def zeroExt {w n : Nat} (v : BitVec w) : BitVec n :=
  BitVec.ofNat n v.toNat

/-- Count leading zeros -/
def clz {w : Nat} (v : BitVec w) : BitVec w :=
  let n := (List.range w).foldl (fun count i =>
    let bitIdx := w - 1 - i
    if count == i && ((v &&& (1#w <<< bitIdx)) == 0#w) then count + 1 else count
  ) 0
  BitVec.ofNat w n

/-- Count trailing zeros -/
def ctz {w : Nat} (v : BitVec w) : BitVec w :=
  let n := (List.range w).foldl (fun count i =>
    if count == i && ((v &&& (1#w <<< i)) == 0#w) then count + 1 else count
  ) 0
  BitVec.ofNat w n

/-- Population count (count number of set bits) -/
def cpop {w : Nat} (v : BitVec w) : BitVec w :=
  let n := (List.range w).foldl (fun count i =>
    if ((v &&& (1#w <<< i)) != 0#w) then count + 1 else count
  ) 0
  BitVec.ofNat w n

end BitVec

end CoralNPU
