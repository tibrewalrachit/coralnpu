package firechip.chip

import org.chipsalliance.cde.config.{Config}

// FireSim targets. Baseline is upstream's FireSimCVA6Config.
class FireSimCVA6CoralNPUConfig extends Config(
  new WithDefaultFireSimBridges ++
  new WithFireSimConfigTweaks ++
  new chipyard.CoralNPUCVA6Config)

class FireSimRocketCoralNPUConfig extends Config(
  new WithDefaultFireSimBridges ++
  new WithFireSimConfigTweaks ++
  new chipyard.CoralNPURocketConfig)
