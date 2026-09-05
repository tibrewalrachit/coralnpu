package chipyard

import org.chipsalliance.cde.config.{Config}

// Rocket host: Verilator-capable; use this for the bare-metal test
// (Chipyard documents CVA6 as VCS-only for software simulation).
class CoralNPURocketConfig extends Config(
  new chipyard.example.WithCoralNPU ++
  new freechips.rocketchip.rocket.WithNHugeCores(1) ++
  new chipyard.config.AbstractConfig)

// CVA6 host: the target SoC for the FireSim F2 run.
class CoralNPUCVA6Config extends Config(
  new chipyard.example.WithCoralNPU ++
  new cva6.WithNCVA6Cores(1) ++
  new chipyard.config.AbstractConfig)
