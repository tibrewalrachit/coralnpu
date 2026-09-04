# Copyright 2025 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Regenerates the FlooNoC network RTL from the FlooGen configuration.
#
# Requires floogen (pip install from a pulp-platform/FlooNoC checkout,
# see README.md). Pin: FlooNoC v0.8.4
# (commit 8a67b860490b3b6b82289c281f5324b287572c8a).

FLOOGEN     ?= floogen
CONFIGS     ?= floogen/coralnpu_mesh_2x2.yml floogen/coralnpu_snitch_mesh_3x3.yml
GENERATED   := generated

.PHONY: all noc-rtl clean

all: noc-rtl

noc-rtl: $(CONFIGS)
	for cfg in $(CONFIGS); do \
	  $(FLOOGEN) rtl -c $$cfg -o $(GENERATED) --no-format; \
	done

clean:
	rm -f $(GENERATED)/*.sv
