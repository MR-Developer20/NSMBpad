# First native tvOS full-game build

Date: 2026-09-03

## Scope

This is the first independent KartPad tvOS build proof. The implementation is
commit `789283113c1efacfa7e0dd4d83e90503869b58d4` on
`codex/tvos-retro-rewind`, based on KartPad `main` at
`ad8ef33810aedbf94f8738d246aa3a0619f3b3ea`. No code from pull request #7 was
incorporated. Pre-push review and external-test hardening are commit
`a6a3668b7eee6b20a61883f066b0167dd3780aa9`.

The target links the private, maintainer-generated dual translation graph for
Original Mario Kart Wii and Retro Rewind. The audited `.app` contains no disc
image, extracted game data, Retro Rewind pack, save, provisioning profile, or
signing identity.

## Toolchain and dependency evidence

- Host: arm64 macOS.
- Xcode: 26.6 (`17F113`).
- tvOS SDK: 26.5.
- Deployment target: tvOS 17.0.
- Dawn source: pinned commit `13abc3bc8ea2d3c2050f9e77a12d012108ceee24`.
- Deterministic tvOS Dawn package SHA-256:
  `e992f36281f153147cb25dd9c77d6bddfd5f7bfa421a3f999139a1dbadadbb57`.

The tvOS Dawn package built from the pinned source and Aurora resolved it from
the local hash-verified package. The complete `KartPadDual` target then compiled
and linked for arm64 `TVOS`; the resulting bundle was 91 MiB.

## Audit result

`scripts/audit-tvos-app.sh` passed for the unsigned app. The audit confirmed:

- bundle identifier `dev.kartpad.tv` and tvOS 17.0 minimum version;
- `TVOS` Mach-O platform metadata with SDK 26.5;
- SDL's UIKit scene delegate;
- declared Extended Gamepad support;
- system-only dynamic dependencies;
- linked Original/Retro Rewind profile-selection and four-player controller
  input contracts;
- presence of the focus-driven Apple TV setup and recovery strings;
- privacy manifest presence; and
- absence of game images, saves, provisioning profiles, and other forbidden
  private material.

Executable SHA-256:
`1c8e3af4864649464f7541e71c83702b8c6434118950a63cb404f9bb51037805`.

Privacy manifest SHA-256:
`343dbc92a22d95a896d5bb894f439d655ac8e15d0fcc7fe72500bd5fcaba1740`.

The bundle is intentionally unsigned. `codesign` reported that the code object
was not signed at all. The final build also passed the wrapper's absolute
repository-path rejection after rebuilding Dawn with deterministic file and
macro prefix maps.

## Pre-push review

The review found and corrected two material tester-path problems before any
push:

- the URL-session completion handler now moves its temporary Retro Rewind ZIP
  before returning, so installation never depends on Apple's temporary
  download-file lifetime; and
- build, audit, game-data staging, backup, and diagnostic scripts now share one
  configurable bundle identifier for testers who must sign under their own
  identifier.

The final source passed 43 unit/contract tests, verification of 330 hunks across
35 patches, shell syntax and plist lint, repository safety and whitespace
checks, a fresh application of the tvOS patch stack, and direct Clang static
analysis of the tvOS Objective-C++ host. The complete app was rebuilt with the
default identifier after a successful custom-identifier build exercise, then
passed the full tvOS app audit at the executable hash above. A separate
diagnostic collector copies only the runtime/controller log directories and
redacts Apple container and Mac user-home paths.

## Remaining acceptance gates

No Apple TV was paired with the build Mac; only an iPad and iPhone were visible
to CoreDevice. This evidence closes compilation, linking, and static artifact
inspection only. It does not establish signing, installation, launch, focus
behavior, controller input, video/audio correctness, Original or Retro Rewind
gameplay, performance, sleep/wake, save durability, or recovery.

The follow-up candidate compiles the repository-owned three-layer KartPad icon
and Top Shelf image into `Assets.car`, which passes structural audit. A physical
Apple TV Home Screen visual check remains open.

The next gate is a narrowly scoped external Apple TV bring-up pass following
`docs/TVOS.md`, using one exact signed build and recorded executable hash. The
candidate must remain labelled physically unaccepted until tester evidence
closes the corresponding rows.

## Published hardware-bring-up candidate

The independent implementation landed on `main` through PR #9 at source commit
`4d32dfac683966ea1cb4f72963deffbe936404da` and was published as
`v0.4.0-preview.1`. The exact clean merged-source tvOS rebuild retained the
executable and privacy-manifest hashes above; its compiled `Assets.car` SHA-256
is `ade08f7ac4e202f7451e1934988e7dda91a0c93067615954f25b8945e2f2368f`.

Two deterministic packages were byte-identical. The published tvOS IPA has
SHA-256
`78dcdf28c947330d480fcc789f0b81b95bafe94497c56f9c26bb6249c5362df1`.
A fresh download matched the local artifact and checksum byte-for-byte and
passed ZIP integrity, provenance, license/notice, app, asset-catalog, privacy,
dependency, signing-residue, local-path, and private-data audits. Physical Apple
TV execution remains open.
