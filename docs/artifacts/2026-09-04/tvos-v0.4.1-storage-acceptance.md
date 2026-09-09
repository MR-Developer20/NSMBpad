# tvOS v0.4.1 storage acceptance

Date: 2026-09-04

Source: [Issue #17 reporter retest](https://github.com/chrissotraidis/kartpad/issues/17#issuecomment-5534726409)

## Exact candidate

- Device: Apple TV 4K (3rd generation), `AppleTV14,1`
- OS: tvOS 26.5/26.6, build `23L773`
- App: KartPad 0.4.1 build 4
- IPA: `KartPad-v0.4.1-tvos-unsigned.ipa`
- IPA SHA-256: `ca62f6e00e0b5260ddb6b836ae2cda969d3bc5655ba4bd3dac19aa9406249e49`
- Installation: re-signed in place with the reporter's personal team profile
- Input: Bluetooth Extended Gamepad

## Accepted result

The reporter confirmed all four checks requested for the public storage
hotfix:

1. `Library/Caches/KartPad/Config.toml` was created and written, with no Cocoa
   error 513 on launch or profile change.
2. Original Mario Kart Wii and Retro Rewind both launched and loaded their
   assets from Caches.
3. NAND/save and settings changes survived normal app termination and relaunch.
4. `scripts/backup-tvos-state.sh` copied the cache-root state over the
   CoreDevice connection without error.

This accepts the `v0.4.1` Application Support-to-Caches correction and closes
Issue #17. It does not prove the exact `v0.4.2` binary or its A12 compiler
baseline, restore from backup, sleep/wake, forced termination, cache-purge
recovery, multi-controller behavior, long-soak performance, or live Retro WFC.
tvOS remains an experimental hardware-bring-up platform.

## Follow-up observation

At nominal thermal state, the reporter observed approximately 60 FPS with
16.6 ms average frame time. Under prolonged load at a Serious thermal state,
heavy scenes fell to approximately 50 FPS. They also reported that 2.0x or 2.5x
render scale looked substantially sharper than the current 1.0x default while
remaining at 60 FPS under nominal thermals. These are one-device observations,
not accepted defaults or broad performance claims; the render-scale suggestion
is tracked in `docs/TECH-DEBT.md`.
