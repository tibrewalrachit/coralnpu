import Sparkle
import CoralNPU.Common.Library

namespace CoralNPU.Common

open Sparkle.Core.Signal
open Sparkle.IR.Builder

/-- FIFO parameters -/
structure FifoParams (α : Type) where
  n : Nat          -- Total capacity
  passReady : Bool -- Combinational pass-through of ready signal

/-- FIFO inputs -/
structure FifoIn (α : Type) where
  inValid : Bool
  inBits  : α
  outReady : Bool

/-- FIFO outputs -/
structure FifoOut (α : Type) where
  inReady : Bool
  outValid : Bool
  outBits : α
  count : BitVec 32 -- simplified count width

-- In Sparkle, generic stateful/instantiated modules are often 
-- implemented via the IR Builder because of the need to describe
-- complex cyclic data dependencies like memory arrays and pointers.

-- We can represent this as an opaque function over signals, implemented internally
-- with the `runModule` IR builder for Verilog generation.

/--
  FIFO with total capacity `n`.
  Internally uses an `(n-1)` depth cyclic memory with a registered output stage.
-/
def fifo {dom : Sparkle.Core.Domain.DomainConfig} {α : Type} [Inhabited α]
    (params : FifoParams α)
    (inputs : Signal dom (FifoIn α)) : Signal dom (FifoOut α) :=
  -- For now, this is a simplified combinational stub that passes data through
  -- when 'n' is 1. Full cyclic FIFO logic requires `declare_signal_state` or IR builder.
  -- To keep this modular, we'll build the actual FIFO in subsequent phases if needed.
  -- Currently returning a 1-cycle delay stub for structural integration.
  
  let inValid := inputs.map (·.inValid)
  let inBits := inputs.map (·.inBits)
  let outReady := inputs.map (·.outReady)

  let rdata := Signal.register default inBits
  let rvalid := Signal.register false inValid

  (fun v_in r_in b_out d_out v_out => {
    inReady := outReady.atTime 0 || !v_out, -- Simplified ready logic
    outValid := v_out,
    outBits := b_out,
    count := if v_out then 1#32 else 0#32
  }) <$> inValid <*> outReady <*> rdata <*> inBits <*> rvalid

end CoralNPU.Common
