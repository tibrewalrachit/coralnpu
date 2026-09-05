// Linux user-space Coral NPU loader for the Chipyard/FireSim CVA6 SoC.
// Mirrors tests/coralnpu.c (bare-metal) using /dev/mem mmap. Prints
// "CORALNPU PASS" or "CORALNPU FAIL: <reason>" and exits 0 / 1.
//
//   coralnpu-run [--base 0x60000000] [--ctrl 0x60040000] [--timeout-ms N]
#define _GNU_SOURCE
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>
#include "coralnpu_fw.h"

#define WIN_BYTES   0x40000UL   /* ITCM/DTCM/CSR window */
#define CTRL_BYTES  0x1000UL
#define OFF_ITCM    0x00000UL
#define OFF_DTCM    0x10000UL
#define OFF_CSR     0x30000UL
#define CSR_RESET   (OFF_CSR + 0x0)   /* [0] core reset, [1] clock gate */
#define CSR_PC      (OFF_CSR + 0x4)
#define CSR_STATUS  (OFF_CSR + 0x8)   /* [0] halted, [1] fault */
#define CTRL_CTRL   0x0               /* [0] soft_reset, [1] irq */
#define CTRL_STATUS 0x4               /* [0] halted [1] fault [2] wfi */

static volatile uint32_t *win, *ctrl;
static inline void w32(volatile uint32_t *b, unsigned long off, uint32_t v) { b[off / 4] = v; __sync_synchronize(); }
static inline uint32_t r32(volatile uint32_t *b, unsigned long off) { __sync_synchronize(); return b[off / 4]; }

static int fail(const char *why) { printf("CORALNPU FAIL: %s\n", why); fflush(stdout); return 1; }

int main(int argc, char **argv)
{
  unsigned long base = 0x60000000UL, cbase = 0x60040000UL;
  long timeout_ms = 2000;
  for (int i = 1; i < argc; i++) {
    if (!strcmp(argv[i], "--base") && i + 1 < argc) base = strtoul(argv[++i], NULL, 0);
    else if (!strcmp(argv[i], "--ctrl") && i + 1 < argc) cbase = strtoul(argv[++i], NULL, 0);
    else if (!strcmp(argv[i], "--timeout-ms") && i + 1 < argc) timeout_ms = strtol(argv[++i], NULL, 0);
    else { fprintf(stderr, "usage: %s [--base A] [--ctrl A] [--timeout-ms N]\n", argv[0]); return 2; }
  }
  int fd = open("/dev/mem", O_RDWR | O_SYNC);
  if (fd < 0) { perror("open /dev/mem"); return fail("cannot open /dev/mem"); }
  win = mmap(NULL, WIN_BYTES, PROT_READ | PROT_WRITE, MAP_SHARED, fd, base);
  ctrl = mmap(NULL, CTRL_BYTES, PROT_READ | PROT_WRITE, MAP_SHARED, fd, cbase);
  if (win == MAP_FAILED || ctrl == MAP_FAILED) { perror("mmap"); return fail("mmap of NPU window failed"); }

  printf("coralnpu: window 0x%lx ctrl 0x%lx, %d firmware words\n", base, cbase, CORALNPU_FW_WORDS);

  /* 1. release async reset (power-on: held) */
  w32(ctrl, CTRL_CTRL, 0x0);
  printf("coralnpu: CTRL=0x%x STATUS=0x%x\n", r32(ctrl, CTRL_CTRL), r32(ctrl, CTRL_STATUS));

  /* 2. core reset + clock gate while loading TCMs */
  w32(win, CSR_RESET, 0x3);
  if (r32(win, CSR_RESET) != 0x3) return fail("CSR RESET readback != 3 (AXI slave not responding?)");

  /* 3. load ITCM, verify, clear result words */
  for (int i = 0; i < CORALNPU_FW_WORDS; i++) w32(win, OFF_ITCM + 4 * i, coralnpu_fw[i]);
  for (int i = 0; i < CORALNPU_FW_WORDS; i++)
    if (r32(win, OFF_ITCM + 4 * i) != coralnpu_fw[i]) return fail("ITCM readback mismatch");
  w32(win, OFF_DTCM + 0, 0); w32(win, OFF_DTCM + 4, 0); w32(win, OFF_DTCM + 8, 0);

  /* 4. start */
  w32(win, CSR_PC, 0x0);
  w32(win, CSR_RESET, 0x1);
  w32(win, CSR_RESET, 0x0);

  /* 5. wait for halted */
  struct timespec t0, t; clock_gettime(CLOCK_MONOTONIC, &t0);
  uint32_t status = 0;
  for (;;) {
    status = r32(win, CSR_STATUS);
    if (status & 0x3) break;
    clock_gettime(CLOCK_MONOTONIC, &t);
    long ms = (t.tv_sec - t0.tv_sec) * 1000 + (t.tv_nsec - t0.tv_nsec) / 1000000;
    if (ms > timeout_ms) break;
    usleep(100);
  }
  printf("coralnpu: CSR STATUS=0x%x CTRL.STATUS=0x%x\n", status, r32(ctrl, CTRL_STATUS));
  if (!(status & 0x1)) return fail("timeout waiting for halted");
  if (status & 0x2) return fail("fault asserted");

  uint32_t r0 = r32(win, OFF_DTCM + 0), r1 = r32(win, OFF_DTCM + 4), r2 = r32(win, OFF_DTCM + 8);
  printf("coralnpu: DTCM[0]=0x%08x DTCM[1]=0x%08x DTCM[2]=0x%08x\n", r0, r1, r2);
  if (r0 != CORALNPU_FW_EXPECT0 || r1 != CORALNPU_FW_EXPECT1 || r2 != CORALNPU_FW_EXPECT2)
    return fail("DTCM result mismatch");
  printf("CORALNPU PASS\n");
  fflush(stdout);
  return 0;
}
