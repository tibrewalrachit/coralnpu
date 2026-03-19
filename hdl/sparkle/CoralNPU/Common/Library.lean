import Sparkle
import CoralNPU.Parameters
import CoralNPU.Interfaces
import CoralNPU.BitVec

namespace CoralNPU

open Sparkle.Core.Signal

-- ============================================================================
-- BitVec Extensions (Pure Lean functions for use in Signals)
-- ============================================================================

-- namespace BitVec
-- ============================================================================
-- Signal Utilities 
-- ============================================================================

namespace Library

/-- MuxOR: if valid is true, returns data, otherwise returns 0 -/
def muxOR {dom : Sparkle.Core.Domain.DomainConfig} {w : Nat} 
    (valid : Signal dom Bool) (data : Signal dom (BitVec w)) : Signal dom (BitVec w) :=
  Signal.mux valid data (Signal.pure 0#w)

/-- MuxOR for booleans: if valid is true, returns data, otherwise returns false -/
def muxORBool {dom : Sparkle.Core.Domain.DomainConfig}
    (valid : Signal dom Bool) (data : Signal dom Bool) : Signal dom Bool :=
  Signal.mux valid data (Signal.pure false)

/-- Pairwise MuxOR reduction for a List of (valid, data) pairs.
    Returns the bitwise OR of all valid data elements. -/
def muxORReduce {dom : Sparkle.Core.Domain.DomainConfig} {w : Nat}
    (items : List (Signal dom Bool × Signal dom (BitVec w))) : Signal dom (BitVec w) :=
  items.foldl (fun acc (v, d) => acc ||| muxOR v d) (Signal.pure 0#w)

/-- Min: returns the minimum of two signals -/
def min {dom : Sparkle.Core.Domain.DomainConfig} {w : Nat}
    (a b : Signal dom (BitVec w)) : Signal dom (BitVec w) :=
  Signal.mux ((· < ·) <$> a <*> b) a b

/-- MinU: returns the unsigned minimum of two signals -/
def minU {dom : Sparkle.Core.Domain.DomainConfig} {w : Nat}
    (a b : Signal dom (BitVec w)) : Signal dom (BitVec w) :=
  Signal.mux ((· < ·) <$> a <*> b) a b -- In Lean 4 BitVec < is unsigned by default. Use .slt for signed.

/-- MinS: returns the signed minimum of two signals -/
def minS {dom : Sparkle.Core.Domain.DomainConfig} {w : Nat}
    (a b : Signal dom (BitVec w)) : Signal dom (BitVec w) :=
  Signal.mux (BitVec.slt <$> a <*> b) a b

/-- MaxU: returns the unsigned maximum of two signals -/
def maxU {dom : Sparkle.Core.Domain.DomainConfig} {w : Nat}
    (a b : Signal dom (BitVec w)) : Signal dom (BitVec w) :=
  Signal.mux ((· > ·) <$> a <*> b) a b

/-- MaxS: returns the signed maximum of two signals -/
def maxS {dom : Sparkle.Core.Domain.DomainConfig} {w : Nat}
    (a b : Signal dom (BitVec w)) : Signal dom (BitVec w) :=
  Signal.mux ((BitVec.slt · ·) <$> b <*> a) a b

/-- SignExt: Sign-extends a signal to a wider width `n` -/
def signExt {dom : Sparkle.Core.Domain.DomainConfig} {w n : Nat}
    (s : Signal dom (BitVec w)) : Signal dom (BitVec n) :=
  BitVec.signExt <$> s

/-- ZeroExt: Zero-extends a signal to a wider width `n` -/
def zeroExt {dom : Sparkle.Core.Domain.DomainConfig} {w n : Nat}
    (s : Signal dom (BitVec w)) : Signal dom (BitVec n) :=
  BitVec.zeroExt <$> s

/-- UIntToOH: One-hot encode an index signal. Returns a BitVec of width `n`. -/
def uintToOH {dom : Sparkle.Core.Domain.DomainConfig} (n : Nat) {w : Nat}
    (idx : Signal dom (BitVec w)) : Signal dom (BitVec n) :=
  (fun i => 1#n <<< i.toNat) <$> idx

end Library

end CoralNPU
