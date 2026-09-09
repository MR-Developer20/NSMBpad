import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


class AppleIdentityFocusTests(unittest.TestCase):
    def test_sdl_fix_is_scoped_idempotent_and_fails_on_unknown_source(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source = root / 'src/video/uikit/SDL_uikitviewcontroller.m'
            source.parent.mkdir(parents=True)
            source.write_text('selector:@selector(textFieldTextDidChange:)\n'
                              '                   name:UITextFieldTextDidChangeNotification\n'
                              '                 object:nil];')
            command = ['cmake', f'-Dsdl_SOURCE_DIR={root}', '-P',
                       str(ROOT / 'cmake/PatchSDLUIKitTextFocus.cmake')]
            subprocess.run(command, check=True, capture_output=True)
            patched = source.read_bytes()
            self.assertIn(b'object:textField]', patched)
            subprocess.run(command, check=True, capture_output=True)
            self.assertEqual(patched, source.read_bytes())
            source.write_text('changed upstream observer')
            self.assertNotEqual(subprocess.run(command, capture_output=True).returncode, 0)

    def test_identity_is_prominent_and_pending_edits_are_explicit(self):
        ios = (ROOT / 'apple/ios/KartPadRuntimeOverlayHost.mm').read_text()
        mac = (ROOT / 'apple/macos/KartPadMacShell.mm').read_text()
        self.assertIn('systemImageNamed:@"externaldrive"', ios)
        self.assertIn('@" · name pending"', ios)
        self.assertIn('@" · deletion pending"', ios)
        self.assertIn('KartPadStagePlayerName', mac)
        self.assertIn('KartPadStageLicenseRename', mac)
        self.assertIn('KartPadStageLicenseDeletion', mac)
        self.assertIn('@"Save for Next Launch"', mac)


if __name__ == '__main__':
    unittest.main()
