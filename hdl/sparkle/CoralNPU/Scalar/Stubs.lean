import Sparkle
import CoralNPU.Parameters
import CoralNPU.Interfaces
import CoralNPU.Common.Library
import CoralNPU.Scalar.Alu
import CoralNPU.Scalar.Bru

namespace CoralNPU.Scalar

open Sparkle.Core.Signal
open Sparkle.IR.Builder
open CoralNPU.BitVec
open CoralNPU.Library

-- Fetch Stub
def fetch {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters) : Signal dom Bool :=
  Signal.pure true

-- Decode Stub
def decode {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters) : Signal dom Bool :=
  Signal.pure true

-- LSU Stub  
def lsu {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters) : Signal dom Bool :=
  Signal.pure true

-- CSR Stub
def csr {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters) : Signal dom Bool :=
  Signal.pure true

-- FaultManager Stub
def faultManager {dom : Sparkle.Core.Domain.DomainConfig} (p : Parameters) : Signal dom Bool :=
  Signal.pure true

end CoralNPU.Scalar
