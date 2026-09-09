# Apple v0.4.8 release verification

- PR: https://github.com/chrissotraidis/kartpad/pull/83
- Release source: `b144925eee394a38aedbd5813b21a73bbc1f6f3b`
- Version: 0.4.8, build 22.
- Release: https://github.com/chrissotraidis/kartpad/releases/tag/v0.4.8

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| KartPad-v0.4.8-ios-unsigned.ipa | 40,793,799 | `989ed540ef1f8a2feb572abba113705cb7a0a7cc943aae517a31dc22bc0d4d65` |
| KartPad-v0.4.8-macos-arm64.zip | 37,607,770 | `9e2c3d5614cdd77730a889babab9fb1e417f70530fbd4503b9860a87fd0d2540` |

Both packages were generated twice from the merged source with identical
bytes. Anonymous fresh GitHub downloads matched the local packages exactly
and passed the complete extracted iOS/macOS and public-distribution audits.
The iOS runtime source also matched a fresh preparation of the committed
patch stack. No audit was bypassed; the Mac audit's expected version and
identity-menu markers were updated with the product changes.

Validation: 68 Python tests, 16 native host tests, floating-stick Simulator
input fixture, and real SDL/UIKit native text-focus fixture passed. The Mac
identity popup was checked live; an accessory-view sizing defect found during
review was fixed before release. Typing/backspace and cancellation were
verified without saving the test name.

The locally development-signed candidate installed and launched in place on
iPhone 14 and iPad Pro 12.9-inch (6th generation). Both devices' NAND and Retro
Rewind saves matched their latest pre-install backups byte-for-byte. The iPad
chooser continued to show its installed Retro Rewind 6.12.7 profile. No app
was uninstalled, no data was cleared, and no private inputs were published.

Physical floating-stick ergonomics, all orientation/lifecycle combinations,
extended gameplay and production-online acceptance remain distinct checks.
The user's confirmation of the corrected Mac popup is not treated as proof
of all those gates. Android remains separate and is not part of this release.

This evidence note follows the release source commit; it does not change the
source identity or provenance embedded in the published archives.
