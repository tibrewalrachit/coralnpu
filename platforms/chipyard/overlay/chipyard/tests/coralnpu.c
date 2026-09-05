// Bare-metal Coral NPU smoke test for Chipyard (runs on the host core).
//
//   1. release the NPU's async reset (wrapper CTRL.soft_reset = 0)
//   2. hold the core in reset + clock-gated (CSR RESET = 3, the power-on value)
//   3. write the RV32 firmware into ITCM, clear the DTCM result words
//   4. PC_START = 0, RESET = 1 (ungate clock), RESET = 0 (release reset)
//   5. poll STATUS.halted, check STATUS.fault, read the DTCM results
//
// Memory map (see platforms/chipyard/README.md in the coralnpu repo).
#include <stdio.h>
#include <stdint.h>
#include "mmio.h"
#include "coralnpu_fw.h"

#define NPU_BASE          0x60000000UL
#define NPU_ITCM          (NPU_BASE + 0x00000UL)
#define NPU_DTCM          (NPU_BASE + 0x10000UL)
#define NPU_CSR           (NPU_BASE + 0x30000UL)
#define NPU_CSR_RESET     (NPU_CSR + 0x0)   /* [0] core reset, [1] clock gate */
#define NPU_CSR_PC_START  (NPU_CSR + 0x4)
#define NPU_CSR_STATUS    (NPU_CSR + 0x8)   /* [0] halted, [1] fault */
#define NPU_CTRL          0x60040000UL
#define NPU_CTRL_CTRL     (NPU_CTRL + 0x0)  /* [0] soft_reset (por 1), [1] irq */
#define NPU_CTRL_STATUS   (NPU_CTRL + 0x4)  /* [0] halted [1] fault [2] wfi */

#define POLL_LIMIT 200000

int main(void)
{
  uint32_t status = 0;
  int i;

  printf("coralnpu: releasing async reset\n");
  reg_write32(NPU_CTRL_CTRL, 0x0);
  printf("coralnpu: CTRL.STATUS=0x%x (expect halted=0)\n", reg_read32(NPU_CTRL_STATUS));

  /* Core reset + clock gate asserted while the TCMs are loaded. */
  reg_write32(NPU_CSR_RESET, 0x3);
  if (reg_read32(NPU_CSR_RESET) != 0x3) {
    printf("coralnpu: FAIL CSR RESET readback 0x%x != 0x3\n", reg_read32(NPU_CSR_RESET));
    return 1;
  }

  for (i = 0; i < CORALNPU_FW_WORDS; i++)
    reg_write32(NPU_ITCM + 4 * i, coralnpu_fw[i]);
  for (i = 0; i < CORALNPU_FW_WORDS; i++) {
    uint32_t rb = reg_read32(NPU_ITCM + 4 * i);
    if (rb != coralnpu_fw[i]) {
      printf("coralnpu: FAIL ITCM readback word %d: 0x%08x != 0x%08x\n", i, rb, coralnpu_fw[i]);
      return 1;
    }
  }
  reg_write32(NPU_DTCM + 0, 0);
  reg_write32(NPU_DTCM + 4, 0);
  reg_write32(NPU_DTCM + 8, 0);
  printf("coralnpu: loaded %d firmware words into ITCM\n", CORALNPU_FW_WORDS);

  reg_write32(NPU_CSR_PC_START, 0x0);
  reg_write32(NPU_CSR_RESET, 0x1);   /* release clock gate, keep reset */
  reg_write32(NPU_CSR_RESET, 0x0);   /* release reset: core runs */

  for (i = 0; i < POLL_LIMIT; i++) {
    status = reg_read32(NPU_CSR_STATUS);
    if (status & 0x3) break;
  }
  printf("coralnpu: CSR STATUS=0x%x after %d polls, CTRL.STATUS=0x%x\n",
         status, i, reg_read32(NPU_CTRL_STATUS));
  if (!(status & 0x1)) {
    printf("coralnpu: FAIL timeout waiting for halted\n");
    return 1;
  }
  if (status & 0x2) {
    printf("coralnpu: FAIL fault asserted\n");
    return 1;
  }

  uint32_t r0 = reg_read32(NPU_DTCM + 0);
  uint32_t r1 = reg_read32(NPU_DTCM + 4);
  uint32_t r2 = reg_read32(NPU_DTCM + 8);
  printf("coralnpu: DTCM[0]=0x%08x DTCM[1]=0x%08x DTCM[2]=0x%08x\n", r0, r1, r2);
  if (r0 != CORALNPU_FW_EXPECT0 || r1 != CORALNPU_FW_EXPECT1 || r2 != CORALNPU_FW_EXPECT2) {
    printf("coralnpu: FAIL expected 0x%08x 0x%08x 0x%08x\n",
           CORALNPU_FW_EXPECT0, CORALNPU_FW_EXPECT1, CORALNPU_FW_EXPECT2);
    return 1;
  }
  printf("coralnpu: PASS\n");
  return 0;
}
