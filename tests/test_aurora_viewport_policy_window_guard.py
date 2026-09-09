from __future__ import annotations

import unittest
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
PATCH_NAME = "aurora-viewport-policy-window-guard.patch"


class AuroraViewportPolicyWindowGuardTests(unittest.TestCase):
    def test_policy_change_defers_viewport_reapply_until_window_exists(self) -> None:
        patch = (REPO / "patches" / PATCH_NAME).read_text()
        self.assertIn(
            "if (changed && aurora::window::get_sdl_window() != nullptr)",
            patch,
        )
        self.assertIn("aurora::gx::set_logical_viewport", patch)
        self.assertIn("aurora::gx::set_logical_scissor", patch)

    def test_runtime_preparation_applies_window_guard(self) -> None:
        for script_name in (
            "prepare-g7-game-runtime.sh",
            "prepare-ios-game-runtime.sh",
        ):
            script = (REPO / "scripts" / script_name).read_text()
            self.assertIn(PATCH_NAME, script, script_name)


if __name__ == "__main__":
    unittest.main()
