from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class IOSLowLatencyAudioContractTests(unittest.TestCase):
    def test_audio_patch_is_applied_after_the_apple_runtime_patch(self) -> None:
        script = (ROOT / "scripts/prepare-ios-game-runtime.sh").read_text()
        apple_runtime = "wiicompiled-apple-runtime.patch"
        low_latency = "wiicompiled-ios-low-latency-audio.patch"

        self.assertEqual(script.count(low_latency), 1)
        self.assertLess(script.index(apple_runtime), script.index(low_latency))

    def test_policy_is_ios_only_and_keeps_the_existing_fallback(self) -> None:
        patch = (ROOT / "patches/wiicompiled-ios-low-latency-audio.patch").read_text()

        self.assertIn("#if TARGET_OS_IOS", patch)
        self.assertIn('SDL_HINT_AUDIO_DEVICE_SAMPLE_FRAMES, "512"', patch)
        self.assertIn("constexpr uint32_t queueMs = 60", patch)
        self.assertIn("constexpr uint32_t queueMs = 120", patch)


if __name__ == "__main__":
    unittest.main()
