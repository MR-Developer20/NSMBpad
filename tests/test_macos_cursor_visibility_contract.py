from __future__ import annotations

import pathlib
import unittest


REPO = pathlib.Path(__file__).resolve().parents[1]


class MacOSCursorVisibilityContractTests(unittest.TestCase):
    def test_runtime_patch_removes_timer_hide_and_restores_cursor_for_settings(self) -> None:
        patch = (REPO / "patches/wiicompiled-macos-cursor-visibility.patch").read_text()
        self.assertIn("SDL_ShowCursor();", patch)
        self.assertIn("-        SDL_HideCursor();", patch)
        self.assertIn("-    UpdateCursorAutoHide();", patch)
        self.assertIn("+    SDL_ShowCursor();", patch)

    def test_macos_runtime_preparation_applies_cursor_patch(self) -> None:
        prepare = (REPO / "scripts/prepare-g7-game-runtime.sh").read_text()
        self.assertIn("wiicompiled-macos-cursor-visibility.patch", prepare)


if __name__ == "__main__":
    unittest.main()
