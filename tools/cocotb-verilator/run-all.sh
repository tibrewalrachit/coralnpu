#!/usr/bin/env bash
# End-to-end: host setup -> test ELFs -> riscv-tests -> tuned Verilator model
# -> Coral's core_mini_axi_sim cocotb suite, N tests in parallel.
#   ./run-all.sh [--parallel N] [--threads T] [--tests a,b,c] [--skip-setup] [--skip-build]
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; source "$HERE/env.sh"
PAR=1; TESTS=""; SKIP_SETUP=0; SKIP_BUILD=0
while [ $# -gt 0 ]; do case "$1" in
  --parallel) PAR=$2; shift 2;; --threads) export CORAL_THREADS=$2; shift 2;; --tests) TESTS=$2; shift 2;;
  --skip-setup) SKIP_SETUP=1; shift;; --skip-build) SKIP_BUILD=1; shift;; *) echo "unknown $1" >&2; exit 2;; esac; done
# tests/cocotb/BUILD CORE_MINI_AXI_SIM_TESTCASES
ALL=(core_mini_axi_basic_write_read_memory core_mini_axi_run_wfi_in_all_slots core_mini_axi_slow_bready
     core_mini_axi_write_read_memory_stress_test core_mini_axi_master_write_alignment core_mini_axi_finish_txn_before_halt_test
     core_mini_axi_riscv_tests core_mini_axi_riscv_dv core_mini_axi_csr_test core_mini_axi_exceptions_test
     core_mini_axi_coralnpu_isa_test core_mini_axi_rand_instr_test core_mini_axi_burst_types_test core_mini_axi_float_csr_test
     unreachable_prefetch_fault core_mini_axi_frm_test)
[ -n "$TESTS" ] && IFS=, read -r -a ALL <<< "$TESTS"
RES=$CORAL_WORK/results; BUILD=$CORAL_WORK/sim_build; mkdir -p "$RES"
[ $SKIP_SETUP = 1 ] || "$HERE/setup-host.sh"
if [ $SKIP_BUILD = 0 ]; then
  "$HERE/build-elfs.sh"; "$HERE/build-riscv-tests.sh"
  /usr/bin/time -f "verilate+compile: %es wall, %MkB maxrss" python3 "$HERE/run_cocotb.py" --sv "$CORAL_SV" --repo "$CORAL_REPO" --build-dir "$BUILD" --build-only --threads "$CORAL_THREADS" --jobs "$CORAL_JOBS" 2>&1 | tail -3
fi
echo "running ${#ALL[@]} tests, $PAR in parallel, $CORAL_THREADS verilator threads each"
start=$(date +%s)
printf '%s\n' "${ALL[@]}" | xargs -P "$PAR" -I{} bash -c '
  t={}; s=$(date +%s)
  python3 "'"$HERE"'/run_cocotb.py" --sv "'"$CORAL_SV"'" --repo "'"$CORAL_REPO"'" --build-dir "'"$BUILD"'" --no-build --tests "$t" --results "'"$RES"'/$t.xml" > "'"$RES"'/$t.log" 2>&1
  rc=$?; echo "$t rc=$rc $(( $(date +%s)-s ))s"'
echo "total: $(( $(date +%s)-start ))s"
python3 - "$RES" <<'PY'
import sys, glob, xml.etree.ElementTree as ET
tot=fail=0
for f in sorted(glob.glob(sys.argv[1]+"/*.xml")):
    for tc in ET.parse(f).iter("testcase"):
        if tc.find("skipped") is not None: continue
        tot+=1; bad = tc.find("failure") is not None or tc.find("error") is not None; fail+=bad
        print(("FAIL " if bad else "PASS ") + tc.get("name") + "  %.1fs" % float(tc.get("time", 0)))
print("== %d tests, %d failed" % (tot, fail)); sys.exit(1 if fail else 0)
PY
