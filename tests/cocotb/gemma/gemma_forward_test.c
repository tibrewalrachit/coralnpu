/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Runs Gemma greedy decoding on the NPU against whatever model image the
// testbench has loaded into the WTCM. The testbench writes `prompt_tokens`
// and `prompt_len`/`gen_len`, runs to halt, then checks `generated_tokens`,
// `final_hidden` and the perf counters.

#include <stdint.h>

#include "sw/gemma/gemma_mmio.h"
#include "sw/gemma/gemma_model.h"

#define SECTION_DATA __attribute__((section(".data"))) __attribute__((aligned(16)))

SECTION_DATA uint32_t prompt_tokens[16];
SECTION_DATA uint32_t prompt_len = 0;
SECTION_DATA uint32_t gen_len = 0;
SECTION_DATA uint32_t generated_tokens[16];
SECTION_DATA float final_hidden[GEMMA_MAX_HIDDEN];
// 0 = did not run; 1 = OK; 2+ = gemma_init failure code + 1.
SECTION_DATA uint32_t test_status = 0;
// mcycle count of the whole generation loop, for tokens/sec estimates.
SECTION_DATA uint32_t decode_cycles = 0;

static GemmaModel model;

static inline uint32_t mcycle(void) {
  uint32_t v;
  asm volatile("csrr %0, mcycle" : "=r"(v));
  return v;
}

int main(void) {
  int rc = gemma_init(&model);
  if (rc != 0) {
    test_status = (uint32_t)rc + 1;
    return rc;
  }
  uint32_t start_cycles = mcycle();
  uint32_t token = prompt_tokens[0];
  uint32_t generated = 0;
  uint32_t steps = prompt_len + gen_len - 1;
  for (uint32_t i = 0; i < steps; ++i) {
    uint32_t next = gemma_decode(&model, token,
                                 (i == steps - 1) ? final_hidden : 0);
    if (i + 1 < prompt_len) {
      token = prompt_tokens[i + 1];  // teacher-forced prompt
    } else {
      generated_tokens[generated++] = next;
      token = next;
    }
  }
  decode_cycles = mcycle() - start_cycles;
  test_status = 1;
  return 0;
}
