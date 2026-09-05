# Coral NPU smoke-test firmware. Runs on the NPU's scalar core out of ITCM.
# Build: rv32imf, NO compressed extension (Coral reuses the C encoding space).
#
# NPU-local addresses (CoreMiniAxi default memory map):
#   ITCM 0x00000000 (8 KiB)   DTCM 0x00010000 (32 KiB)   CSR 0x00030000
#
# Writes three words to DTCM+0 and halts with mpause:
#   DTCM+0  = 0x11223344 + 0x55667788 = 0x6688AACC   (integer add)
#   DTCM+4  = 1.5f + 2.25f            = 0x40700000   (FPU: 3.75f)
#   DTCM+8  = 0xC0DE0001                              (done marker)
    .section .text
    .globl _start
_start:
    lui   a0, 0x10            # a0 = DTCM base (0x00010000)
    li    t0, 0x11223344
    li    t1, 0x55667788
    add   t2, t0, t1
    sw    t2, 0(a0)
    li    t3, 0x3fc00000      # 1.5f
    fmv.w.x f0, t3
    li    t4, 0x40100000      # 2.25f
    fmv.w.x f1, t4
    fadd.s  f2, f0, f1
    fmv.x.w t5, f2
    sw    t5, 4(a0)
    li    t6, 0xC0DE0001
    sw    t6, 8(a0)
    .word 0x08000073          # mpause -> halted
1:  j     1b
