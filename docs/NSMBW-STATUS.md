# NSMBW-Pad status

Retarget of this KartPad fork from Mario Kart Wii (RMCP01) to New Super Mario
Bros. Wii PALv1 (SMNP01 rev 0), per the plan uploaded 2026-09-02
(`docs/NSMBW-PLAN.md`).

## Environment note (read first)

This document's entries so far were produced in a **Linux container**: no
Xcode, no macOS, no physical iPhone/iPad, no legally-dumped NSMBW disc image.
Any plan gate that requires building/running on a Mac or a physical iOS
device, or extracting a real disc, **cannot be executed here** and is marked
`NOT RUN` below, not assumed or simulated. Do not read a `NOT RUN` row as
"expected to fail" — it means exactly what it says: nobody has run it yet in
an environment that can.

## Naming note

The plan asks for `docs/STATUS.md`, `docs/JOURNAL.md`, `docs/KNOWN-ISSUES.md`.
Those filenames are already in use by KartPad's own (MKWii) status/journal/
known-issues, which are large, pre-existing, and out of scope for this task —
they were not overwritten. NSMBW-specific state lives in `docs/NSMBW-*.md`
instead. The plan text itself is `docs/NSMBW-PLAN.md`.

## Open gates

| Gate | State | Notes |
|---|---|---|
| P0 — Baseline & orientation | **PARTIAL** | See below. Device/Mac MKWii baseline not run in this environment. |
| P1 — Disc validation & extraction | **DRAFTED, NOT RUN** | `builder/profiles/smnp01-rev0.json` and `scripts/prepare-disc-nsmbw.sh` exist as untested drafts. No disc image available; LZ decompression step intentionally left unimplemented (script hard-stops there) rather than faked. |
| P2 — Binary analysis | NOT RUN | Needs P1 output. |
| P3 — First translation (DOL only) | NOT RUN | Needs P2 output. |
| P4 — Input prototype | NOT RUN | Needs a running game to observe KPAD/shake behavior against. |
| P5 — Boot to first frame | NOT RUN | Needs a Mac (Aurora/Dawn/Xcode toolchain). |
| P6 — Title & first level | NOT RUN | Needs a physical iOS device. |
| P6b — External display & local multiplayer | NOT RUN | Needs a physical iOS device + TV/controllers. |
| P7 — Completeness & performance | NOT RUN | Needs a physical iOS device. |

### P0 detail

Done in this environment (read-only / repo-local, no build toolchain required):
- `docs/EDIT-SURFACE.md` generated via `rg` (plan §P0.2): 41 files reference
  `RMCP01`, 19 reference `mkwii`/`mariokart` case-insensitively, 248 reference
  bare `kart` (dominated by the `KartPad` product name — see the caution note
  in that file).
- Read KartPad's `README.md`, `RIGHTS_AND_LICENSES.md`, and `docs/` for gate
  structure and evidence-ledger conventions.
- `.gitignore` updated: added `maps/`, `logs/`, and `*.dol`/`*.rel`/`*.rel.LZ`
  patterns. Verified with `git check-ignore` that `maps/`, `logs/`, and a
  planted `dummy.dol` are now ignored, and that `input/` (real source, not
  meant to be ignored) is not.

**Not done, and why:**
- "Confirm the fork builds and runs MKWii on a physical iOS device, and on
  Mac" (P0.1) — impossible in this container. No Xcode, no macOS, no device.
- "Confirm `check-repo-safety.sh` ... still holds" / "Confirm the iOS audit
  script (`audit-ios-game-app.sh`) still rejects game data" (P0.4, second
  half) — `check-repo-safety.sh` uses BSD `stat -f` (macOS-only syntax) and
  `audit-ios-game-app.sh` requires `plutil` and a built `.app` bundle;
  neither tool is available on Linux. The `.gitignore`/`git check-ignore`
  half of P0.4 was verified directly instead (see above), which does not
  require either script.
- Branch: this session's harness assigns a fixed branch
  (`claude/plan-execution-6mjalm`) rather than the plan's suggested
  `nsmbw-retarget`; work is on that assigned branch instead.

### A discrepancy worth flagging, not fixing here

`docs/STATUS.md` (KartPad's own, MKWii) contains extremely detailed claims of
physical-device acceptance, multi-hour audio soaks, and full four-player
races. `runtime/generated/` on disk contains exactly two translated function
files (`func_80001000.cpp` under `g6/` and `g7/`), against
`builder/profiles/mkwii-rmcp01-rev0.json`'s own stated
`expectedGeneratedFunctions: 29637`. That gap was surfaced to the user before
this NSMBW work began; no attempt was made here to audit or correct it, and
none of this NSMBW work relies on those MKWii claims being true. Flagging it
again here so it isn't lost: treat `docs/STATUS.md`'s hardware-acceptance
claims as unverified until someone actually checks them.

## What P1 needs to actually run

- A user-supplied, legally-dumped NSMBW **PALv1** (`SMNP01` rev 0) disc image.
- `nodtool 2.0.0-alpha.9` (present in this fork's tooling already).
- Observation of nodtool's actual output layout for the four RELs (compressed
  path/name), which `scripts/prepare-disc-nsmbw.sh` currently guesses at and
  deliberately refuses to proceed past.
