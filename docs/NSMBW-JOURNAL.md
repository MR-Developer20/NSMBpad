# NSMBW-Pad engineering journal

Append-only. See `docs/NSMBW-STATUS.md` for current gate state.

## 2026-09-02 — P0 partial (environment-limited) + P1 draft scaffolding

- Environment: Linux container (no Xcode, no macOS, no physical iOS device,
  no NSMBW disc image). Flagged this to the user before starting; agreed
  scope was "scaffolding only, no fabricated hardware/device evidence."
- Also flagged: KartPad's own `docs/STATUS.md` claims extensive physical
  hardware acceptance, but `runtime/generated/` on disk holds only 2
  translated function files against a profile-declared expectation of
  29,637. Not investigated further here; noted so it isn't mistaken for a
  baseline this NSMBW work can lean on.
- P0.1 (MKWii device+Mac baseline confirmation): **not run** — needs
  hardware this session doesn't have.
- P0.2 (edit-surface inventory): ran `rg -l 'RMCP01'` (41 files),
  `rg -lI 'mkwii|mariokart' -i` (19 files), `rg -lI 'kart' -i` (248 files,
  mostly `KartPad`-branding false positives). Saved to
  `docs/EDIT-SURFACE.md`.
- P0.3: read `README.md`, `RIGHTS_AND_LICENSES.md`, `docs/STATUS.md`,
  `docs/KNOWN-ISSUES.md`, `docs/JOURNAL.md` (head), `scripts/check-repo-safety.sh`.
- P0.4: `.gitignore` updated (`maps/`, `logs/`, `*.dol`/`*.rel`/`*.rel.LZ`).
  Verified via `git check-ignore` that `maps/`, `logs/`, and a planted
  `dummy.dol` are ignored, and `input/` is not. Could **not** run
  `check-repo-safety.sh` (uses BSD `stat -f`, not available on Linux) or
  `audit-ios-game-app.sh` (needs `plutil` + a built `.app`, macOS-only).
- P0.5: skipped creating a `nsmbw-retarget` branch — this session's harness
  pins work to `claude/plan-execution-6mjalm` instead. `docs/NSMBW-STATUS.md`
  created as the gate table (not `docs/STATUS.md`, to avoid clobbering
  KartPad's existing one — see naming note there). `docs/NSMBW-PLAN.md` is
  the plan file itself, copied in for in-repo reference.
- P1 (draft, not run): copied the MKWii profile shape into
  `builder/profiles/smnp01-rev0.json` for `SMNP01` rev 0, using the five
  MD5s from plan §2.1. REL load addresses left `null` — plan §2.1 asserts
  they're deterministic but says to verify empirically at P2; not
  fabricated here. `expectedGeneratedFunctions` left `null` — plan §2.3
  says the real count is unpublished; did not carry over MKWii's number.
  Wrote `scripts/prepare-disc-nsmbw.sh` (new file, alongside rather than
  replacing `scripts/prepare-disc.sh`, which still works for MKWii) —
  extracts via `nodtool`, checks Wii disc magic, and MD5-verifies
  `wiimj2d.dol` and all four RELs against plan §2.1. It deliberately
  `exit 1`s before the LZ-decompression step, which is unimplemented
  because nodtool's actual output layout for the RELs has never been
  observed against a real image in this environment.
- `docs/NSMBW-KNOWN-ISSUES.md` created with KI-N001 (World 7-Tower rev-0
  softlock, upstream retail bug, not a translation defect) per plan
  §2.1.1's instruction to file this before P6. Filed now since it costs
  nothing and there's no reason to wait.
- Next gate: P1, for real — needs the user to supply a legally-dumped
  NSMBW PALv1 disc image, and needs to run in an environment with
  `nodtool` actually exercised against it (this container has cargo/rustc
  but has not attempted an install or a real extraction).
