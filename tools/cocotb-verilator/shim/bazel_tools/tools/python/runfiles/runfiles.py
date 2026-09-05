"""Minimal stand-in for bazel's runfiles library, for running the Coral cocotb
tests outside bazel. Rlocation("coralnpu_hw/<path>") is resolved against the
colon-separated roots in CORAL_RUNFILES_ROOTS (first match wins)."""
import os

class _Runfiles:
    def __init__(self):
        self.roots = [r for r in os.environ.get("CORAL_RUNFILES_ROOTS", "").split(":") if r]
    def Rlocation(self, path):
        rel = path[len("coralnpu_hw/"):] if path.startswith("coralnpu_hw/") else path
        for root in self.roots:
            p = os.path.join(root, rel)
            if os.path.exists(p):
                return p
        return os.path.join(self.roots[0], rel) if self.roots else rel

def Create():
    return _Runfiles()
