# NSMBW-Pad — Claude Code Execution Plan

Static recompilation of **New Super Mario Bros. Wii** to a native Apple ARM64 app. **iOS/iPadOS primary, macOS secondary.**

**Premise: you are working inside a fork of `chrissotraidis/kartpad`, already cloned and building for Mario Kart Wii.** This is a retarget, not a greenfield build.

Read this file and `docs/STATUS.md` at session start. Do not re-derive facts in §2 — they are verified. Resuming mid-gate: `tail -60 docs/JOURNAL.md`; otherwise skip the journal.

**Retirement rule.** Most of this is needed once. When a phase's gate passes and its reference material is no longer cited by any remaining phase, **cut those sections into `docs/archive/PLAN-retired.md`** and leave a one-line stub pointing there. §2.4 and §4 retire after P3. This file should shrink as the project progresses, not grow. Never delete — archive, so it stays greppable.

---

## Operating rules

**Context discipline — non-negotiable:**
- Never `cat`/`view` a binary, `.dol`, `.rel`, `.map`, or generated `.c/.cpp` translation output. Use `rg`, `head -n 40`, `wc -l`, `xxd | head`.
- Never paste build logs into context. Redirect to `logs/`, then `rg -i 'error|fatal|undefined' logs/x.log | head -50`.
- Generated translation output lives in `private/` and `build/`. **Never read it.** Treat as opaque.
- Symbol maps are 30k+ lines. Always query with `rg 'pattern' maps/file.txt | head`, never open whole.
- One task = one gate. Finish, log, stop. Do not chain phases speculatively.

**State persistence (survives compaction):**
- `docs/JOURNAL.md` — append-only. After every gate: date, command run, result, hashes, next gate. 5 lines max per entry.
- `docs/STATUS.md` — current single source of truth. Overwrite the "Open gates" table, don't append.
- On session start: read this file + `docs/STATUS.md` only. Read `JOURNAL.md` tail only if resuming mid-gate: `tail -60 docs/JOURNAL.md`.

**The fork is the source of truth, not the web:**
- Upstream versions, patch sets, and build flags are already pinned in the fork's lockfiles, `patches/`, and `scripts/`. **Read those, don't search GitHub.** If a version question arises, `rg` the fork first.
- KartPad's own `README.md`, `RIGHTS_AND_LICENSES.md`, and `docs/` are prior art written by someone who solved this exact problem once. Consult them before inventing an approach.
- Every MKWii→NSMBW change should be a diff against a working baseline. If you can't express a change as a diff, you're probably rebuilding something that already works.

**Output discipline:**
- No summaries of what you just did unless asked. The journal entry is the summary.
- Ask before any step >30 min of compute or >5 GB disk.
- If a gate fails twice the same way, stop and report. Do not improvise a third approach.

**Never commit:** disc images, extracted game files, decompressed RELs, translated C/C++, saves, signing material, `.map` files if license-unclear. Enforce via `.gitignore` + `scripts/check-repo-safety.sh` (port from KartPad).

---

---

## 1. Mission & scope

Produce a native ARM64 app that runs NSMBW via ahead-of-time PowerPC→ARM64 translation. No emulator, no JIT, no interpreter at runtime.

**In scope:** single-player through World 1, then full game. Local 4-player. Saves. Touch + gamepad input including synthesized motion. **External display output with the device as a controller surface** (§2.8) — new capability, not inherited.
**Out of scope (v1):** online, Coin Battle vs. modes over network, mod loading (Newer/Kamek) — deferred.

**Reference target:** NSMBW **PALv1** (`SMNP01` rev 0) — decided and fixed. Chosen because the decomp and symbol maps target PALv1; the known rev 0 quirks are accepted rather than patched (§2.1.1). Other regions and revisions fail closed.

**Platform strategy — read carefully, this is a deliberate split:**
- **iOS/iPadOS is the product.** Touch controls are a first-class design surface, not a fallback. Device-class memory limits, thermals, and app lifecycle are acceptance constraints from P5 onward, not P7 polish.
- **macOS is the debug surface during P2–P5.** The translated module is identical on both; only the host shell differs. Fighting REL relocation or a missing GX path while also fighting code signing, device deployment, and on-device debugging is two problems at once. Bring up on Mac, then land on device.
- **This inverts KartPad's own order.** KartPad did Mac-first and reached physical-device acceptance only after substantial additional work — meaning the iOS path is the less-proven one in the code you're inheriting. Budget accordingly: iOS-specific defects are expected to outnumber Mac ones, and `apple/ios/` plus the `*-ios-*` patches deserve more scrutiny than the Mac shell.
- Do not ship a Mac build as the milestone. Every gate from P6 must be demonstrated **on a physical iPhone or iPad**, with the Mac build as corroboration only.

---

---

## 2. Verified facts (do not re-research)

### 2.1 Binary structure
Five code files. `main.dol` renamed `wiimj2d.dol` on disc, plus four LZ-compressed RELs, dynamically loaded and relocated after the health-and-safety screen.

| File | PALv1 MD5 |
|---|---|
| `wiimj2d.dol` | `ddab9e5dca53d8c18bf4051b927e822e` |
| `d_basesNP.rel` | `17096d0ed441d44a0c31039138a8d7f8` |
| `d_en_bossNP.rel` | `f8cffd634edbec6c1bc210dab02c1e32` |
| `d_enemiesNP.rel` | `458f1aa94706dde1a8f2f9d97ff1f35c` |
| `d_profileNP.rel` | `393bf12ef4254dd1ea1366d5b06fbebb` |

REL size order (largest→smallest): `d_basesNP` > `d_enemiesNP` > `d_en_bossNP` > `d_profileNP`.

**Critical property:** the RELs load at **deterministic fixed addresses every run** (per NSMBW-Decomp docs). This is what makes static recomp tractable — treat their load addresses as constants, verify empirically in P2.

Decompress `.rel.LZ` with NSMBW-Decomp's `tools/uncompress_lz.py`.

### 2.1.1 Region and revision — PAL 50 Hz question (checked)

**Concern raised:** PAL console titles historically ran at 50 Hz with correspondingly slower physics, which would matter enormously for a platformer.

**Finding: no evidence of a PAL speed penalty for NSMBW.**
- The Cutting Room Floor's dedicated **Version Differences** page for NSMBW documents regional and revision changes in detail — title screens, banners, credits, collision, Shield-port asset handling — and lists **no timing, framerate, or speed difference** for PAL. A 5/6-speed PAL build is exactly the kind of thing that page exists to record.
- Speedrun.com's NSMBW leaderboards show **no region split and no region-based timing rules**. If PAL ran at 50 Hz, region categories would be mandatory there.
- The 50 Hz problem is a cartridge-era artifact of tying game logic to the display refresh. Wii-era titles are generally not built that way, and PAL Wii consoles expose a 60 Hz output mode.

**Confidence: good, not conclusive.** This is absence of documented difference across two sources that would be expected to record it — not a positive statement that PAL NSMBW is natively 60 Hz. **Confirm empirically at P5**, which is nearly free: once the game boots, measure the guest's vertical-retrace cadence. 60 Hz → settled. 50 Hz → stop and reconsider the profile before investing further.

**Separate finding worth acting on — PALv1 carries a known softlock.** TCRF records that NA, PAL, and Japanese versions received a **revision 2** built in early 2010, which changed World 7-Tower's boss-battle tileset collision to make the platform fully solid. In revision 1, a player popped from a bubble under the floor can become stuck; if the others join them, the level softlocks until the timer runs out. **The plan pins PALv1 because that's what the decomp and symbol maps target — so the port would ship a bug Nintendo already fixed at retail.**

**DECIDED: stay on PAL rev 0 (PALv1).** Full map and decomp alignment is worth more than the collision fix. The revision-2 fix is **not** ported; the profile stays faithful to rev 0.

Consequences to handle, not ignore:
- **File it in `docs/KNOWN-ISSUES.md` as an upstream retail bug, before P6.** Wording should be explicit that it is present in the original rev 0 disc and is not introduced by the port.
- **It is not a translation defect — do not chase it.** A tester who hits a W7-Tower softlock in a four-player session will reasonably assume the recomp broke something and may burn days bisecting translation output. The entry exists mainly to stop that.
- **Faithfulness is the standard for anything similar.** If another rev 0 quirk surfaces, reproduce it rather than fixing it, unless it blocks completion outright. Journal any case where that rule feels wrong instead of quietly diverging.
- Revisiting the collision fix as an optional post-v1 patch stays available, but it is out of scope and off the critical path.

### 2.2 Engine layers
RVL SDK (C, hardware) → nw4r (C++ graphics/audio/text) → EGG (Nintendo internal C++ framework) → game code.
Game class prefixes: `f` framework, `s` state+math, `m` EGG/nw4r/RVL wrappers, `snd` sound, `c` utilities, `d` game-specific.
Same SDK lineage as Mario Kart Wii → Aurora/WiiCompiled's existing GX and RVL coverage carries over substantially.

**Indirect dispatch is the dominant translation problem here, not jump tables.** `d_profileNP.rel` is the actor **profile registry**: NSMBW instantiates essentially every actor by profile ID through a table of constructor function pointers. So indirect calls aren't an edge case to patch around — they are the spawn path for everything on screen, crossing REL boundaries constantly.

Consequences:
- The N64Recomp `LOOKUP_FUNC(ctx->rN)` pattern (§2.5) is mandatory, not optional, and needs a **complete address→translated-function map spanning `main.dol` and all four RELs**. A gap doesn't fail at build time — it fails when some enemy first spawns, three worlds in.
- The lookup sits on a hot path. Measure its cost early; a naive map lookup per actor construction may show up in P7 profiling.
- Build a coverage check: enumerate every profile-table entry and assert each resolves to a translated function. Run it as a P3/P5 gate rather than discovering holes through gameplay.

### 2.3 Scale
- KartPad/MKWii: **29,065 translated functions**.
- NSMBW: Ninji's hash-cracking work targeted **"over 30,000 hashes"** in `main.dol` alone — that's functions **and** data symbols, DOL only, RELs excluded. Not directly comparable. Exact DOL+REL function count is **unpublished**. Plan for "same order of magnitude, likely larger."

### 2.3.1 Correctness oracle — you don't inherit one

KartPad verifies physics accuracy against **ghost replays**: Mario Kart Wii hands you a deterministic recorded-input format for free, so "did the translation change the physics" has a mechanical answer. **NSMBW has no equivalent.** Without a substitute, translation correctness reduces to "it looked right," which is exactly the standard KartPad's own docs refuse to accept.

**Proposed substitute: Dolphin `.dtm` movie playback.** `.dtm` is Dolphin's deterministic input-recording format, and the NSMBW TAS community has published movies. Replaying a known-good `.dtm` against the recompiled build and comparing outcomes (level completion, position at checkpoints, death/no-death) gives a repeatable oracle for the same class of bug ghosts catch in KartPad.

Caveats to establish before relying on it: `.dtm` determinism assumes a matching game revision and emulator settings, so a PALv1 movie is required; and the input format must be injectable at the same KPAD layer the rest of the input stack uses (§2.6). If it works, it doubles as a regression harness — rerun after every translation change.

Treat "no oracle exists" as an open risk until this is proven, and say so in `docs/STATUS.md` rather than implying accuracy is verified.

### 2.4 Dependencies

**Already vendored and pinned by the fork — use the fork's pins, do not re-resolve:**

| Purpose | Component | Where in fork |
|---|---|---|
| Recompiler | WiiCompiled (GPLv3, .NET 8) | lockfile + `patches/wiicompiled-*.patch` |
| GX compat layer | Aurora (`encounter/aurora`, MIT) | lockfile + `patches/aurora-*.patch` |
| WebGPU backend | Dawn (Metal on Apple) | lockfile, CMake |
| Disc extraction | `nodtool` `2.0.0-alpha.9` | `scripts/prepare-disc.sh` |
| DiscIO | Dolphin-derived, iOS-patched | `patches/dolphin-ios-discio*.patch` |
| Touch controls | SunPad snapshot (GPLv3) | `apple/third_party/sunpad/` |

If a pin looks wrong, `rg` the fork's lockfile and `patches/` — that's the answer. Only search upstream if the fork is silent.

**New, NSMBW-specific — must be added to the fork:**

| Purpose | URL | Notes |
|---|---|---|
| Binary splitting | `github.com/encounter/decomp-toolkit` (`dtk`) | Rust single binary. KartPad may not use it; add as a tool dep. |
| dtk template | `github.com/encounter/dtk-template` | Reference config shape |
| NSMBW decomp | `github.com/NSMBW-Community/NSMBW-Decomp` | PALv1, CodeWarrior mwcceppc Wii/1.1. Early-stage — **reference only, not a prerequisite** |
| Decomp docs | `nsmbw-community.github.io/NSMBW-Decomp/docs/` | Best public engine narrative |
| Address maps | `github.com/NSMBW-Community/NSMBW-Maps` | Address maps present; symbol maps "soon" |
| Symbol maps | `rootcubed.dev/nsmbw-symbols` + `github.com/RootCubed/nsmbw_hashAttack` | Recovered from Shield TV port hash table |
| Manifest template | `Wiicompiled/projects/examples/generic-dol.yml` | Already in the vendored checkout — read it there |
| Mod framework (reference) | Kamek | Documents hook addresses + engine structs |

Symbol map provenance: the Chinese Nvidia Shield TV port shipped a symbol table hashed with `h = 0x1505; for c in name: h = (h * 33) ^ c`, extracted from `libnsmb.so`. Cracked by Ninji/RoadrunnerWMC. Use maps as **reference data to seed analysis** — do not redistribute.

### 2.5 Prior-art config idioms to borrow
- **N64Recomp** (TOML): stub functions, skip functions, patch single instructions; `LOOKUP_FUNC(ctx->rN)` for indirect calls; relocation macros on `lui/addiu/load/store` for overlays; single-file output mode for replacement functions.
- **XenonRecomp** (PowerPC, TOML + XenonAnalyse): jump tables detected via `mtctr r0` pattern, "no fully generic solution"; explicit `functions` property for failed boundary detection; `invalid_instructions` to skip inter-function data; **mid-asm hooks** to inject C++ at an address with `return`/`jump_address` control. Provides no runtime — that's on you.

**Universal hard blockers:** jump tables, indirect/virtual calls, self-modifying code, hand-written asm, dynamic-module relocation modeling.

### 2.6 Input — the NSMBW-specific hard problem
NSMBW is played with the **Wii Remote held sideways** (D-pad + 1/2), or Remote+Nunchuk. Classic Controller is not the primary scheme (unlike MKWii). Motion is core, not cosmetic:
- **Shake → Spin Jump / mid-air spin** (accelerometer)
- **Shake → pick up / carry**
- **Tilt → see-saw platforms, aim light beams** (accelerometer tilt)
- Propeller suit and other power-ups triggered by shake

Game reads via RVL **WPAD** and its high-level wrapper **KPAD** (`KPADRead`/`KPADReadEx`), which carries buttons, stick/extension data, and **accelerometer data**.

Community precedent (GBAtemp Classic Controller Hacks): synthesize motion by locating where accel data is loaded into the `read_kpad_acc()`-style path and injecting float values. That function "changed a lot over the Wii's lifespan" → game-specific, must be located in NSMBW's map.

**This is the #1 novel risk. Prototype it in P4, not at the end.**

#### 2.6.1 Control scheme — sideways Wii Remote (specified)

**The target the whole input layer emulates: a Wii Remote held sideways with its top pointing LEFT.** D-pad under the left thumb, 1/2 under the right thumb. Every input source (touch, controller, gyro) synthesizes into that one virtual remote.

**Touch surface — derive it from the game, don't design it.** The touch layout presents the sideways Wii Remote's own buttons, matching what NSMBW natively expects and what it draws on screen. The retail manual confirms the game renders its own prompts: on-screen controller explanations and icons assume Wii-Remote-only play, even when a Nunchuk is connected. **That makes the game self-documenting — whatever glyph it draws is the control the touch surface should show.** Read the prompts in-game rather than inventing labels.

Widely documented sideways scheme (confirm against the game's own icons in P4, don't ship on secondhand sources): D-pad = move/duck/enter pipes, **2** = jump, **1** = run / grab / shoot, **+** = pause. Walkthrough sources describe carry-and-throw as holding **1** plus a shake, which is consistent with 1 being the run/grab button. Whether **A** and **−** carry gameplay functions is unconfirmed — if the game never prompts for them, they don't belong on the touch surface.

**The two exceptions that cannot follow this rule:** shake and tilt have *no* native buttons — they're motion. These need invented affordances: a dedicated Spin/Shake control, and a tilt control for see-saws and light beams. Style them distinctly from the native button glyphs so it's visually clear which controls exist on a real remote and which are this port's additions.

Build all of it into SunPad's editable layout system rather than hardcoding positions.

**Controller face buttons — bind by POSITION, never by label.** The scheme in Xbox-layout terms is Y→A, X→shake, A→1, B→2. Nintendo controllers swap A/B and X/Y labels relative to that, so binding by label would move every button. Bind positionally so the physical layout is identical on every controller:

| Physical position | Guest input | Xbox label | Switch label |
|---|---|---|---|
| **Top** | Wii **A** | Y | X |
| **Left** | **Shake** (spin jump / pick up / power-up) | X | Y |
| **Bottom** | Wii **1** | A | B |
| **Right** | Wii **2** | B | A |

This is a real ambiguity, not a hypothetical: SDL ships `SDL_HINT_GAMECONTROLLER_USE_BUTTON_LABELS` precisely because the two conventions disagree, and it **defaults to label** ("0" = report by position as though Xbox, "1" = report by label). Apple's GameController framework has produced reported prompt/label mismatches with Switch Pro controllers on iPadOS. **So do not assume which convention `GCController` gives you** — detect the controller's product category, test all four face buttons on a real Switch Pro or Joy-Con pair, and keep a per-category override table. Journal the observed convention in P4.

**Shoulders and triggers:**

| Physical input | Guest input | Notes |
|---|---|---|
| **Left trigger** (L2/ZL) | Tilt **left** | Analog travel → tilt magnitude, proportional |
| **Right trigger** (R2/ZR) | Tilt **right** | Analog travel → tilt magnitude, proportional |
| **Either shoulder** (L1/R1) | **Shake** | Same action as the left face button — a second, more reachable binding |
| **+ / −** | Start / Select | Menu/pause |

Analog triggers suit tilt because NSMBW's tilt is a continuous angle — see-saws and light beams respond to how far, not whether. Shake is discrete and timing-critical, so digital buttons are the right shape; giving it both a face button and both shoulders means it's always reachable mid-jump.

**D-pad orientation — VERIFY, do not assume.** With the remote rotated 90° counter-clockwise (top to the left), the physical D-pad no longer matches screen directions. Geometrically:

| Player intends | Physical D-pad direction on the sideways remote |
|---|---|
| Right | Physical **Down** (the remote's bottom now faces right) |
| Left | Physical **Up** |
| Up | Physical **Right** |
| Down | Physical **Left** |

**The open question is where the rotation happens.** WPAD/KPAD deliver raw button bits in the *remote's own* frame, and the game applies its own horizontal-orientation handling. Since you inject at the KPAD read layer — upstream of whatever the game does — injecting pre-rotated bits would **double-rotate** if the game also rotates. Whether NSMBW expects raw or oriented input is unverified and must be established empirically.

Keep this behind **one constant** (a rotation enum: none / 90° CW / 90° CCW / 180°) so flipping it is a one-line change. Decisive test in P4/P6: bind the control that should mean "right" and press it in a level.
- Mario walks right → correct.
- Mario ducks → rotated 90° the wrong way; flip the enum.
- Mario walks left → 180° off.

Test in gameplay **and** on the world map — confirm one setting serves both rather than assuming it does.

**Other implementation requirements:**
- **Both triggers pressed → neutral.** Sum the signed values rather than last-wins; a player rolling between them should pass through level.
- **Deadzone and full-scale calibration.** Map trigger travel to the tilt range the detector actually reads — establish that range empirically in P4, don't guess a normalized 0–1.
- **Shake retrigger cadence.** A synthetic spike can fire far faster than a human can shake a Wii Remote. Rate-limit to a plausible physical cadence or spin jump becomes a rapid-fire exploit. Derive the interval from the detector's own debounce.
- **Digital-trigger fallback.** Where `GCController` reports a digital-only trigger, full-press = maximum tilt in that direction.
- **Confirm what each Wii button actually does in-game** before finalizing. The mapping above fixes button *identity*; P4 should confirm from the map and the retail manual what A, 1, and 2 each drive in NSMBW, and flag any button that turns out unused or double-bound.
- **Check for a native Classic Controller binding conflict.** NSMBW has some CC support of its own; confirm what the game already expects on L/R before overriding, and document collisions in `docs/KNOWN-ISSUES.md`.
- **Real gyro is separate and opt-in.** DualSense, DualShock 4, Switch Pro, and Joy-Con expose motion through `GCMotion`. Offer real gyro tilt behind a default-off setting, mirroring KartPad's Motion Steering precedence (§2.7). Triggers stay the always-available default so behavior is identical across every controller.
- **Precedence chain:** controller face/shoulder/trigger input > touch controls > device or controller gyro. Backgrounding clears live motion state, as upstream already does.
- **One injection path.** Touch Spin, face-button shake, shoulder shake, and gyro all converge on the same accel-injection function, so the waveform stays tunable in one place.

### 2.7 KartPad multi-input — verified behavior (inherited, works)

From KartPad's README and status table. This is real, tested code you are inheriting — do not rebuild it.

**macOS:**
- Keyboard bridge: WASD steer, U/Return = A, M/Delete = B, E = R/drift, Left Shift = L/item, arrows = D-pad, Space = Start, Tab = Select. Native **Controls…** panel (`Cmd-/`) keeps the mapping visible.
- Native controller discovery, remapping, and **four stable local slots**, implemented separately from the keyboard fallback.

**iOS/iPadOS:**
- **Touch is Player 1 only.** There is no scheme for multiple touch players on one device.
- **Controller handoff:** the first extended controller takes Player 1, clears held touch input, and hides touch controls by default. Disconnecting it restores touch. Additional controllers hold stable Player 2–4 slots.
- **Players 2–4 publish independent retail KPAD channels** — the multi-controller plumbing already exists at the KPAD level, which is exactly the layer NSMBW reads.
- **••• → Multiplayer…** reports connected controllers, shows Player 1–4 assignment, and opens controller setup guidance.
- **••• → Motion Steering…** is default-off, offers recenter, inversion, and 0.5×/1×/2× sensitivity. Touch can override it, physical controllers take priority, backgrounding clears live motion state. **Reuse this state-precedence model for NSMBW's shake/tilt** — it already solves who-wins-when.

**What is NOT yet validated upstream (inherit the gap, not the assumption):**
- Status table: "Keyboard plus four independent Classic-controller slots; **two-player full-race evidence passes**." Two, not four.
- Explicitly open: "a complete three- and four-player result path," and "physical controller takeover and restoration" on a physical device.

**Consequence for NSMBW-Pad:** 4-player is architecturally supported and unproven. NSMBW is a 4-player couch game, so this moves from a nice-to-have to a core scenario — you will be the one proving the 3–4 player path, not inheriting proof of it.

### 2.8 External display — KartPad does NOT handle this

**Verified absence.** KartPad's README, project map, status table, and `docs/KNOWN-ISSUES.md` (which contains exactly one entry, KI-001, about build disk space) contain **no mention of external displays, UIScreen, scene lifecycle, or AirPlay**. The closest thing is `aurora-ios-opaque-letterbox.patch` and "opaque fitted-output bands," which fit the guest output to the *device's own* screen.

So: connect an iPhone to a TV today and you get **default system mirroring** — the device's whole screen, letterboxed into the TV, touch controls and all, at whatever latency the transport imposes. That is a bad experience and an open opportunity.

**Why this matters more for NSMBW than for MKWii:** NSMBW is a four-player couch game whose defining mode is everyone on one screen. A TV plus controllers is arguably the *correct* way to play it. And §2.8 says touch is Player 1 only — so external display is the natural home for multiplayer.

**The improvement to build — device as controller, TV as screen:**

Adopt the **scene lifecycle** with a dedicated external-display scene role (`UIWindowSceneSessionRole.externalDisplayNonInteractive`). Modern iOS uses scene roles for this; the older `UIScreenDidConnect`/`UIScreenDidDisconnect` notification path is the legacy approach and is not used by scene-lifecycle apps. Then:

1. **Game renders to the external display at its native resolution and refresh rate.** Not mirrored, not letterboxed into a phone aspect. Pick a display mode matching the guest's 60 Hz cadence.
2. **Device screen becomes a dedicated controller surface** — the SunPad touch layout alone, with the game view removed. This also solves P6's "touch layout obscures gameplay at phone size" risk outright: nothing to obscure.
3. **Seamless attach/detach mid-gameplay.** Connecting or disconnecting must not drop a frame, lose the Metal surface, or interrupt the guest. This is the hard part: Dawn's swapchain and `CAMetalLayer` must be re-created against the new drawable size and refresh rate while the translated game module keeps running. Treat the guest as unaware — it renders to a fixed framebuffer; only presentation changes.
4. **Keep rendering when the device screen locks or dims.** A user playing on a TV with a controller will let the phone sleep. Handle this explicitly; the existing lifecycle code assumes device-screen-is-the-game.
5. **Audio follows the route.** KartPad already passes "live output-device migration" — HDMI and AirPlay routes should inherit that for free. Verify, don't assume.
6. **Distinguish wired from AirPlay and say so.** A USB-C/Lightning AV adapter is low-latency; AirPlay adds enough to hurt a precision platformer. Detect the route and surface a one-line advisory rather than letting the user blame the port for input lag.
7. **Add ••• → Display…** exposing: external output on/off, mode/refresh selection, and whether the device screen shows controls-only or mirrors.

**Failure modes to expect:** swapchain recreation racing the render loop on hot-plug; scale/`nativeBounds` mismatches producing a quarter-size image (a long-standing iOS external-display trap); overscan on TVs that crop; refresh-rate mismatch producing judder that looks like a performance regression but isn't.

### 2.9 What to do with each part of the fork

**LEAVE ALONE — works as-is, game-agnostic:**
- `apple/macos/` — Mac shell, settings, diagnostics
- `apple/ios/` — lifecycle, import, motion integration
- `apple/third_party/sunpad/` — pinned GPLv3 touch component + `•••` menu (editable phone/tablet layouts, safe area, multitouch, accessibility, controller handoff). Keep the snapshot revision, hashes, and attribution intact.
- Generic patches: `aurora-ios-opaque-letterbox`, `aurora-ios-simulator-single-pipeline-worker`, `aurora-present-telemetry`, `dolphin-curl-ios-pipe2`, `dolphin-ios-discio`, `dolphin-ios-discio-coreless`, `wiicompiled-apple-runtime`
- Metal presentation, audio, storage, lifecycle
- `scripts/` build + audit pipeline: `self-build-macos.sh`, `translate-base.sh`, `build-ios-game-app.sh`, `build-ios-device-game-app.sh`, `audit-macos-package.sh`, `audit-ios-game-app.sh`, `check-repo-safety.sh`

**EDIT IN PLACE — reparameterize from `RMCP01` to `SMNP01`:**
- `builder/profiles/` — new PALv1 profile with the five hashes from §2.1
- `scripts/prepare-disc.sh` — five files to extract instead of two, plus LZ decompression
- DiscIO importer call sites — new game ID / revision check

**REPLACE ENTIRELY:**
- WiiCompiled manifest + translation graph — MKWii's `main.dol` + `StaticR.rel` becomes NSMBW's `wiimj2d.dol` + four RELs
- Input adapter — KartPad's tested Classic Controller ABI adapter is the wrong shape for NSMBW (§2.6). New module.

**DELETE:**
- MKWii online/WFC plumbing, Retro Rewind mod support, MKWii-specific runtime patches, ghost-replay physics verification harness (retarget or drop)

---

---

## 3. Repo layout

KartPad's existing tree, plus these additions. Do not restructure what's already there.

```
nsmbw-pad/                                # fork of kartpad
  apple/{macos,ios,third_party/sunpad}/   # unchanged
  patches/                                # + nsmbw-specific patches
  builder/profiles/smnp01-rev0.yml        # NEW: hashes, identity
  translator/nsmbw.yml                    # NEW: WiiCompiled manifest (DOL + 4 RELs)
  input/                                  # NEW: KPAD adapter + motion synthesis
  maps/                                   # NEW: symbol/address maps (gitignored)
  scripts/                                # edited: prepare-disc.sh
  docs/{STATUS,JOURNAL,PERF,KNOWN-ISSUES}.md   # NEW, alongside KartPad's docs
  logs/ ref/ private/ build/              # gitignored
```

---

---

## 4. Prerequisites

The fork already builds MKWii, so KartPad's dev requirements are satisfied: Apple Silicon Mac, macOS 14+, Xcode + CLT, CMake, Ninja, Git, ripgrep, Python 3, .NET 8 SDK, Rust/Cargo, `nodtool 2.0.0-alpha.9`, Dawn (~20 GB scratch, long first build).

**Add only:**
- `dtk` (decomp-toolkit) binary — for DOL/REL splitting and relocation analysis
- User-supplied legally-dumped NSMBW **PALv1** disc image
- CodeWarrior `mwcceppc` (Wii/1.1) via wibo/Wine — **only** if building decomp-derived C++ patches. Not needed for pure recompilation. Defer until something demands it.

**iOS-first does not remove the Mac.** Translation, compilation, and signing happen on the Mac regardless; the device only ever runs the output — there is no on-device translation path and never will be (the upstream project is explicit that the mobile app ships no PowerPC JIT or runtime compiler). Do not scope toward a device-only workflow.

**iOS-first additions:**
- A physical iPhone and/or iPad on the target OS version, provisioned for development. The simulator is insufficient — `aurora-ios-simulator-single-pipeline-worker.patch` exists precisely because simulator GPU behavior diverges.
- Apple Developer account + signing identity for device deployment. Personal-team 7-day provisioning is workable for development; note the re-signing cadence in `docs/STATUS.md` so expiry isn't mistaken for a regression.
- A way to get the user's disc image onto the device — KartPad's on-device DiscIO import path. Verify this works with MKWii on your device **before** P1, so P1 failures are attributable to NSMBW and not to import plumbing.

If the fork does not currently build and run MKWii end to end **on a physical iOS device**, fix that first. A Mac-only baseline is not a sufficient baseline for an iOS-first project.

---

---

## 5. Phases

Each phase ends at a **gate**. Do not start the next phase until the gate passes and is journaled.

### P0 — Baseline & orientation
1. **Confirm the fork builds and runs MKWii on a physical iOS device**, and on Mac. Tag both working states as `baseline-mkwii`. Every later regression is diffed against this. An iOS-first project needs an iOS baseline.
2. Inventory before changing anything: `rg -l 'RMCP01'` and `rg -ril 'mkwii|mariokart|kart'` — this is your complete edit surface. Save the list to `docs/EDIT-SURFACE.md`.
3. Read KartPad's `README.md` + `RIGHTS_AND_LICENSES.md` + `docs/`. Note its gate structure and evidence-ledger format; reuse both rather than inventing new ones. Pay particular attention to anything it documents about iOS device acceptance — that's the path you're depending on most.
4. Verify `check-repo-safety.sh` and `.gitignore` still hold after adding `maps/`, `input/`, `logs/`. Plant a dummy `.dol` and confirm it fails. Confirm the iOS audit script (`audit-ios-game-app.sh`) still rejects game data in the bundle.
5. Create `docs/STATUS.md` with the gate table from this file. Create branch `nsmbw-retarget`.

**Gate P0:** MKWii runs on device *and* on Mac from this fork; both audit scripts fail on a planted binary; `docs/EDIT-SURFACE.md` exists. Journal the baseline commit hash, device model, and OS version.


### P1 — Disc validation & extraction
1. Copy the existing `RMCP01` profile to `builder/profiles/smnp01-rev0.yml` and edit: game ID `SMNP01`, rev 0, container hash, the five MD5s from §2.1. Keep KartPad's profile schema — don't redesign it.
2. Edit `prepare-disc.sh` — five files instead of two, `nodtool` extract read-only to `private/`, verify identity + revision + all five hashes, fail closed on any mismatch.
3. Add LZ decompression for the four `.rel.LZ` (port `uncompress_lz.py` logic from NSMBW-Decomp).

**Gate P1:** all five MD5s match §2.1 from the user's own image. Wrong-region image is rejected. Journal hashes.


### P2 — Binary analysis
1. Run `dtk` on `wiimj2d.dol` + four RELs (pass `selfile.sel` for Wii).
2. Fetch NSMBW-Maps / RootCubed symbols into `maps/`. Query with `rg`, never open whole.
3. Produce: function boundary list, inter-module relocation table, section layout, and the **observed REL load addresses**.
4. **Empirically verify** the deterministic-load claim from §2.1 — record actual addresses under Dolphin or via runtime instrumentation. Do not take it on faith.

**Gate P2:** clean split into shiftable objects; relocations rebuilt; four REL base addresses recorded and confirmed stable across ≥3 runs. Journal the addresses.
*Failure modes:* mis-split `.ctors/.dtors/extab/extabindex`; unresolved inter-REL relocations.


### P3 — First translation (DOL only)
1. **Diff base: the fork's working MKWii manifest.** Read it, then read `generic-dol.yml` in the vendored WiiCompiled checkout for the non-MKWii idioms. Write `translator/nsmbw.yml` for `wiimj2d.dol` only; stub REL entry points.
2. Seed function boundaries from `maps/`.
3. Translate → compile for arm64.
4. Expect failures: jump tables, indirect calls, hand-asm. Resolve with explicit function boundaries, `invalid_instructions`-equivalent, and mid-asm hooks. Log each patch in `patches/` with the address and reason.

**Gate P3:** translated DOL compiles clean for arm64; the profile-table coverage check (§2.2) reports every entry resolving to a translated function, or an explicit list of known gaps. Journal function count, patch count, and unresolved profile entries.


### P4 — Input prototype (RUN EARLY, IN PARALLEL WITH P3)
Do not defer. This is the project's kill-switch risk, and on an iOS-first project it is also the primary product surface.
1. Locate NSMBW's KPAD accelerometer read path via `maps/` (search for KPAD/WPAD symbols, then the shake-detection consumer).
2. Build `input/` adapter: buttons via KPAD channel; **synthesize an accel waveform** for shake and a sustained tilt vector for tilt.
3. **Derive the touch layout from the game's own on-screen prompts** (§2.6.1), not from a designed guess. Play far enough to capture the button icons NSMBW draws, build the touch surface to match, and add the two invented affordances (Spin/Shake, tilt) styled distinctly. Use SunPad's editable layout system rather than hardcoding positions. Record the confirmed button-to-action table in `docs/KNOWN-ISSUES.md` and drop any button the game never prompts for.
4. Implement the full §2.6.1 controller scheme: face buttons bound **positionally** (top→A, left→shake, bottom→1, right→2), analog triggers → proportional tilt per side, either shoulder → shake, `GCMotion` gyro opt-in where available. All sources plus touch converge on one accel-injection function. Establish the detector's tilt range and debounce empirically — calibration constants come from measurement.
5. **Resolve the two verification questions.** (a) Test all four face buttons on a real Switch Pro or Joy-Con pair and record whether `GCController` reports by position or by label; build the per-category override table from what you observe. (b) Determine the D-pad rotation convention — whether NSMBW expects raw remote-frame bits or already-oriented input — and set the single rotation constant accordingly.
6. Decide and document how device motion maps in: real Core Motion tilt for see-saws/light beams is the natural fit, but a physical shake gesture competes with holding a phone steady to see the screen. Prefer an on-screen Spin button as default, device motion as an opt-in.
7. Test the detector in isolation if possible; otherwise defer confirmation to P6.

**Gate P4:** the shake-detection function is identified by address, its expected input shape and debounce documented in `docs/KNOWN-ISSUES.md`; the native button-to-action table is confirmed from the game's own prompts and a matching touch layout draft exists; the §2.6.1 scheme is implemented behind the single injection path with measured calibration constants; the observed `GCController` face-button convention and the chosen D-pad rotation value are both journaled.
*If not locatable:* escalate — fallback is a mid-asm patch replacing the detector with a boolean. Note that this changes game behavior and must be documented.


### P5 — Boot to first frame
1. Aurora/Dawn + Apple host layer are already wired and working for MKWii — you are swapping the translated game module underneath them, not rebuilding the stack.
2. Implement the four-REL load/relocation path in the runtime — **the main NSMBW-specific runtime work.** MKWii's single-`StaticR.rel` path is the closest existing code; extend rather than replace.
3. Get past init and the health-and-safety screen where RELs load.
4. Bring this up on **Mac first** — it's the same translated module and a far cheaper debug loop. Then land it on device before declaring the gate.

5. **Expect the sequenced-audio path to be under-tested.** NSMBW's soundtrack is heavily sequenced nw4r (BRSEQ/BRSAR) with dynamic layering — Yoshi drums, the tempo shift when enemies close in. MKWii leans much harder on streamed BRSTM, so if WiiCompiled's audio was exercised mainly on streams, the sequencer is a comparatively cold code path. Get music playing before P6 and confirm the layering reacts, not just that sound comes out.

6. **Measure the guest's vertical-retrace cadence** to close out the PAL 50/60 Hz question (§2.1.1). Cheap once booting; do it here rather than assuming.

**Gate P5:** first Metal frame renders **on a physical iOS device**. Mac-only is a checkpoint, not the gate. Journal both.
*Failure modes:* REL relocation; GX state Aurora doesn't cover for this game; device memory pressure that the Mac never surfaces.


### P6 — Title & first level
1. Title + world-map menu render and respond to touch input.
2. **World 1-1 playable on device, spin jump working via synthesized accelerometer, driven by the touch layout.** This is the input-layer proof and the product proof at once.

**Gate P6:** 1-1 completable start to flagpole on a physical iPhone or iPad, with spin jump, using touch controls only. Then repeat with a connected controller using the §2.6.1 scheme. **Confirm D-pad orientation in gameplay and on the world map** — pressing right walks right, not ducks. **Verify face-button positions are identical on an Xbox-layout and a Switch-layout controller.** Screen recording + journal. *A screenshot is not acceptance — record a completion.* Record the shake retrigger interval that felt right and whether proportional tilt reaches the range see-saws need.
*Failure modes:* nw4r BRLYT/BRLAN layout or font paths unhandled; shake waveform doesn't trip the detector; touch layout obscures gameplay at phone size; trigger travel doesn't cover the tilt range the game reads; shake rate-limit allows spin-spam or blocks legitimate rapid spins; **D-pad double-rotated** (feels 90° off); **face buttons transposed on Switch-layout controllers**.


### P6b — External display & local multiplayer
The one place NSMBW-Pad goes beyond what it inherits (§2.8). Both halves are the same scenario: TV plus controllers.

1. **Decide the scene-lifecycle migration early** — check in P5 whether the inherited `apple/ios/` shell already adopts scenes. If it doesn't, migrating it later is more disruptive than doing it before P6b starts. Journal the decision either way.
2. Add an external-display scene role; render the guest framebuffer to the external display at its native mode. Device screen becomes controls-only.
3. Handle hot-plug: recreate the Dawn swapchain / `CAMetalLayer` against the new drawable size and refresh rate without interrupting the guest. Guest renders to a fixed framebuffer — only presentation changes.
4. Keep rendering when the device screen locks or dims.
5. Detect wired vs. AirPlay; show a one-line latency advisory for AirPlay.
6. Verify audio follows the HDMI/AirPlay route via the inherited output-device migration.
7. Add **••• → Display…**: external output on/off, mode/refresh, device-screen mode (controls-only vs. mirror).
8. **Prove the 3–4 player path** — upstream only has two-player evidence (§2.7). Test controller takeover and restoration on device: first controller claims Player 1 and hides touch, disconnect restores touch, Players 2–4 hold stable KPAD channels through a full level.

**Gate P6b:** a 4-player level completed on a TV with four controllers, plus a hot-plug attach and detach mid-level with no crash, no guest interruption, and no visible corruption. Screen recording + journal, including the transport used (wired or AirPlay) and measured input latency on each.
*Failure modes:* swapchain recreation racing the render loop; scale/`nativeBounds` mismatch producing a quarter-size image; TV overscan cropping; refresh mismatch reading as a perf regression; controller slot reassignment on reconnect.


### P7 — Completeness & performance
1. All worlds, 4-player local, saves, audio soak.
2. **Expect the dominant perf issue to be cold Dawn/Metal shader-pipeline compilation.** KartPad measured a track dropping to ~1.3 FPS on first use, recovering to ~46–54 FPS warm. Build a pre-warmed pipeline cache; measure cold vs. warm explicitly. This hurts more on device than on Mac — measure on device.
3. Evidence ledger: frame-time percentiles, audio-drop accounting, long soak, **thermal behavior and battery drain over a 30-minute session**, and memory headroom against the device's jetsam limit.
4. Verify on both a phone and a tablet — SunPad ships separate layouts for each, and the smaller screen is where the touch scheme will fail first.
5. Profile external-display output separately: a 4K TV is a larger present target than a phone panel, and cold shader compilation on top of that is the worst case. Measure it as its own row, not folded into device numbers.

**Gate P7:** full-game completion evidence on device + cold/warm perf comparison + thermal/memory data in `docs/PERF.md` + at least one `.dtm` replay matching expected outcome (§2.3.1), or a documented statement that no correctness oracle was established.

---

---

## 6. Optional: non-Apple scaffolding

Debug-surface hierarchy when something breaks: **device → Mac → PC**. Mac is the standard debug loop (§1). Drop to PC only if P3/P5 stall badly — upstream WiiCompiled's shipped build path (LLVM-MinGW, D3D12/Vulkan) is its most-tested one, and it isolates translation bugs from anything Apple-specific. **Scaffolding only, outside the fork.** Do not let it drift into a third target; the deliverable is an iOS app.

---

---

## 7. Risk register

| Risk | Trigger | Response |
|---|---|---|
| Motion synthesis fails | P4/P6: shake never fires | Mid-asm patch → boolean button. Document behavior change. Hard product gate. |
| Incomplete REL symbol maps | P2: boundaries unresolved | Manual XenonRecomp-style annotation. Multiplies P2/P3 effort — reassess scope. |
| REL addresses not deterministic | P2 verification fails | Full dynamic relocation modeling in runtime. Major scope increase. |
| Shader compilation stutter | P7 | Pre-warmed pipeline cache; accept as known issue like KartPad. |
| PAL 50 Hz | — | **Checked — largely cleared, see §2.1.1.** No documented speed difference; keep the cheap empirical confirmation at P5. |
| W7-Tower softlock misread as a port bug | P6/P7 | Present in rev 0 by design of the decision in §2.1.1. File in KNOWN-ISSUES before P6 so nobody bisects translation output chasing an upstream retail bug. |
| No physics oracle | P3→P7 | §2.3.1. Establish `.dtm` replay early or accept that correctness is unverified and say so in STATUS. |
| Profile-table gap found late | P5→P7 | Unresolved indirect target fails at first spawn, not at build. Run the coverage check as a gate (§2.2). |
| Sequenced audio path cold | P5 | BRSEQ/BRSAR layering may be less exercised upstream than streamed BRSTM. Test music reactivity, not just presence. |
| Pipeline cache doesn't transfer Mac→iOS | P7 | Metal pipeline caches are GPU-specific. A Mac-warmed cache will not serve an iPhone GPU — generate and ship one per device class. More work than reusing KartPad's approach. |
| `dtk` and WiiCompiled disagree | P2/P3 | WiiCompiled does its own boundary discovery. Check for overlap before wiring both in; two tools producing conflicting metadata about one binary is a nasty bug class. |
| REL unload/reload during play | P2/P5 | Deterministic addresses assume load-once. If any module is unloaded and reloaded mid-session, the static assumption degrades into real relocation modeling. Verify residency explicitly. |
| Paired-single gate assumed transferable | P3 | KartPad's paired-single oracle passes for **MKWii's** usage. NSMBW may use different GQR quantization types — re-verify, don't inherit the pass. |
| Fork baseline broken | P0 | Fix MKWii build before touching anything. Without a known-good baseline, failures are unattributable. |
| Edits leak into game-agnostic code | any | Diff against `baseline-mkwii`. Changes outside `docs/EDIT-SURFACE.md` need justification. |
| Upstream KartPad diverges | any | Pin to a KartPad commit. Do not chase upstream mid-phase; rebase only between gates. |
| iOS path less proven than Mac | P5–P7 | Expected — KartPad reached device acceptance late. Scrutinize `apple/ios/` and `*-ios-*` patches first when a defect appears on device but not Mac. |
| Device memory / jetsam kill | P5–P7 | Measure headroom from first frame, not at P7. Four RELs plus translated code may exceed what MKWii needed. |
| 4-player unusable on one screen | P6b | Touch is Player 1 only (§2.7). External display + controllers is the intended answer, not a workaround. Without a TV, scope device play to 1–2 players. |
| 3–4 player path unproven upstream | P6b | KartPad has two-player evidence only. Budget real time here; you're proving it, not inheriting it. |
| Scene-lifecycle migration needed late | P6b | Check in P5 whether `apple/ios/` already adopts scenes. Retrofitting after P6 is disruptive. |
| Swapchain hot-plug instability | P6b | Recreate against new drawable size on a controlled boundary, not mid-frame. Guest keeps its fixed framebuffer. |
| AirPlay latency blamed on the game | P6b | Detect transport, advise once. Do not let a user diagnose input lag as a game defect. |
| Shake rate-limit mistuned | P4/P6 | Too loose = spin-jump spam exploit; too tight = blocked legitimate rapid spins. Derive from the detector's own debounce, then confirm in play. |
| Trigger travel undershoots tilt range | P4/P6 | Calibrate against the range the detector actually reads, not a normalized 0–1. Digital-trigger controllers need a full-scale fallback. |
| D-pad double-rotated | P4/P6 | Game may already apply sideways orientation. Keep rotation behind one enum; decisive test is pressing "right" in a level. |
| Touch layout invents buttons the game never uses | P4 | Derive from the game's own on-screen prompts; drop anything unprompted. Only shake and tilt are legitimately invented. |
| Face buttons transposed on Switch controllers | P4/P6 | SDL defaults to label-based reporting and `GCController`'s convention is unconfirmed. Bind positionally, test on real Switch hardware, keep a per-category override. |
| Touch scheme fails at phone size | P6 | Test on the smallest target device early; SunPad's per-form-factor layouts exist for this. |
| Signing/provisioning expiry mistaken for regression | any | Record re-signing cadence in `docs/STATUS.md`. Check expiry before debugging a sudden launch failure. |

---

---

## 8. Legal & licensing

Norms these projects follow (descriptive, not legal advice):
- **No game data, ever.** Code only. User supplies their own legally-dumped copy. Audit scripts must **fail the build** if game data, saves, or signing material enter the bundle.
- **Translate locally.** WiiCompiled deliberately does not redistribute translated binaries — the recompiler runs on the user's machine over their own dump. Note: KartPad's `v0.3.0-preview.3` does distribute an unsigned IPA containing translated game logic (no assets) and documents this in `RIGHTS_AND_LICENSES.md` as an unresolved rights question. **Default to local-only translation.**
- **GPLv3 inheritance.** The fork is already GPLv3 (WiiCompiled + SunPad) and stays GPLv3. Preserve KartPad's `RIGHTS_AND_LICENSES.md`, add attribution to KartPad itself as upstream. SunPad's touch component is GPLv3: retain snapshot revision, hashes, attribution. Aurora (MIT), Dawn, SDL, Dolphin-derived code, Crypto++, Abseil, FreeType, libpng each keep their own licenses and notice obligations.
- **Trademark notice** in README: not affiliated with, endorsed by, or associated with Nintendo; marks used only to identify compatibility.
- Symbol maps are RE-derived community data — consume as reference, don't redistribute game code.
- The Shield TV port that the symbol maps derive from is itself documented on TCRF as a distinct release with its own asset and credits differences — useful corroboration that the provenance story in §2.4 is accurate.
- **Provenance here differs from KartPad's.** The NSMBW maps originate from cracking a hashed symbol table extracted from the Shield TV port's `libnsmb.so` (§2.4). That is a different story than anything the upstream project relies on, and Mario is among the properties Nintendo defends most actively. Not legal advice — just noting the risk profile is not identical to the project being forked, and shouldn't be assumed to be.

---

---

## 9. Unverified — confirm before relying on

- **WiiCompiled attribution is ambiguous.** KartPad's own README links `github.com/sonicdcer/WiiCompiled`; other sources point to `patchzyy/Wiicompiled`. Since the fork already vendors and patches a specific revision, **use the fork's lockfile** — it is authoritative for what you're building against. Only resolve the naming question if you need to pull upstream changes.
- Exact NSMBW DOL/REL decompressed byte sizes and combined function count: unpublished.
- Per-REL relocation counts: unpublished.
- NSMBW-Decomp completion %: decomp.dev blocks automated access; visibly early-stage.
- KartPad's online/performance claims are self-reported and marked not-yet-accepted upstream.
