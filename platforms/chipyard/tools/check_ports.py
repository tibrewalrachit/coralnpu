#!/usr/bin/env python3
"""Check that the generated CoreMiniAxi module exposes every port the Chipyard
blackbox (CoralNPU.scala) drives or reads, with the expected widths.
Usage: check_ports.py <CoreMiniAxi.sv or flattened bundle>"""
import re, sys

EXPECTED = {  # name: width in bits
    "io_aclk": 1, "io_aresetn": 1, "io_halted": 1, "io_fault": 1, "io_wfi": 1, "io_irq": 1,
    "io_boot_addr": 32, "io_te": 1,
    "io_dm_req_valid": 1, "io_dm_req_ready": 1, "io_dm_req_bits_address": 32,
    "io_dm_req_bits_data": 32, "io_dm_req_bits_op": 2,
    "io_dm_rsp_valid": 1, "io_dm_rsp_ready": 1, "io_dm_rsp_bits_data": 32, "io_dm_rsp_bits_op": 2,
}
A = {"addr": 32, "prot": 3, "id": 6, "len": 8, "size": 3, "burst": 2, "lock": 1, "cache": 4, "qos": 4, "region": 4}
for port in ("io_axi_slave", "io_axi_master"):
    for ch in ("write_addr", "read_addr"):
        EXPECTED[f"{port}_{ch}_valid"] = 1; EXPECTED[f"{port}_{ch}_ready"] = 1
        for k, w in A.items(): EXPECTED[f"{port}_{ch}_bits_{k}"] = w
    EXPECTED[f"{port}_write_data_valid"] = 1; EXPECTED[f"{port}_write_data_ready"] = 1
    for k, w in {"data": 128, "last": 1, "strb": 16}.items(): EXPECTED[f"{port}_write_data_bits_{k}"] = w
    EXPECTED[f"{port}_write_resp_valid"] = 1; EXPECTED[f"{port}_write_resp_ready"] = 1
    for k, w in {"id": 6, "resp": 2}.items(): EXPECTED[f"{port}_write_resp_bits_{k}"] = w
    EXPECTED[f"{port}_read_data_valid"] = 1; EXPECTED[f"{port}_read_data_ready"] = 1
    for k, w in {"data": 128, "id": 6, "resp": 2, "last": 1}.items(): EXPECTED[f"{port}_read_data_bits_{k}"] = w

src = open(sys.argv[1]).read()
m = re.search(r"^module\s+CoreMiniAxi\s*\((.*?)\);", src, re.S | re.M)
if not m:
    sys.exit("module CoreMiniAxi not found in " + sys.argv[1])
ports, dirs = {}, {}
cur_dir, cur_w = None, 1
for line in m.group(1).split("\n"):
    line = line.split("//")[0].strip().rstrip(",")
    if not line:
        continue
    pm = re.match(r"(input|output|inout)\s+(?:(?:wire|logic|reg)\s+)?(?:\[(\d+):(\d+)\]\s+)?(\w+)$", line)
    if pm:
        cur_dir = pm.group(1)
        cur_w = (int(pm.group(2)) - int(pm.group(3)) + 1) if pm.group(2) else 1
        name = pm.group(4)
    elif re.match(r"^\w+$", line) and cur_dir:   # continuation: same direction/width
        name = line
    else:
        continue
    ports[name] = cur_w
    dirs[name] = cur_dir
bad = 0
for name, w in sorted(EXPECTED.items()):
    if name not in ports:
        print("MISSING", name); bad += 1
    elif ports[name] != w:
        print("WIDTH  ", name, "sv=%d expected=%d" % (ports[name], w)); bad += 1
extra_inputs = [p for p in ports if p not in EXPECTED and dirs[p] == "input"]
for p in extra_inputs:
    print("UNTIED INPUT", p); bad += 1
print("%d expected ports checked, %d problems, %d ports in module" % (len(EXPECTED), bad, len(ports)))
sys.exit(1 if bad else 0)
