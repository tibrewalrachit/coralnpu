# Local run: Coral cocotb suite on tuned Verilator 5.050

Host: 4 vCPU / 15 GB sandbox, cocotb 2.0.0, Verilator 5.050, model built with
`-O3 --x-assign fast --x-initial fast --noassert -CFLAGS "-O3 -march=native" --threads 2`.
Verilate + C++ compile: 3477 s (58 min) with 4 build jobs. Tests: 2 in parallel.

| Test case | Result | Real time (s) |
|---|---|---|
| core_mini_axi_basic_write_read_memory | PASS | 135.2 |
| core_mini_axi_burst_types_test | PASS | 96.6 |
| core_mini_axi_coralnpu_isa_test | PASS | 0.2 |
| core_mini_axi_csr_test | PASS | 47.4 |
| core_mini_axi_exceptions_test | PASS | 0.2 |
| core_mini_axi_finish_txn_before_halt_test | PASS | 0.0 |
| core_mini_axi_float_csr_test | PASS | 0.0 |
| core_mini_axi_frm_test | PASS | 0.2 |
| core_mini_axi_master_write_alignment | PASS | 0.1 |
| core_mini_axi_rand_instr_test | PASS | 4.4 |
| core_mini_axi_riscv_dv | PASS | 3.8 |
| core_mini_axi_riscv_tests | PASS | 6.3 |
| core_mini_axi_run_wfi_in_all_slots | PASS | 0.1 |
| core_mini_axi_slow_bready | PASS | 0.2 |
| core_mini_axi_write_read_memory_stress_test | PASS | 29.8 |
| unreachable_prefetch_fault | PASS | 0.3 |

**16 run, 0 failed.**

Two fixes were needed to get here and are now in the scripts: test programs must be built with `-O1` (bazel fastbuild) or trap-heavy tests exceed the 1000-cycle halted timeout, and cocotb must be 2.0.0 (2.1 changes handle types).
