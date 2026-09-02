# NSMBW-Pad known issues

## KI-N001 — World 7-Tower boss-room softlock (upstream retail bug, PALv1 rev 0)

- Severity: upstream retail bug, present in the original disc — not a
  translation defect.
- Source: The Cutting Room Floor's NSMBW Version Differences page. NA, PAL,
  and Japanese releases received a revision 2 in early 2010 that made the
  World 7-Tower boss-room platform fully solid. In revision 1 (and, per this
  project's decision, revision 0/PALv1), a player popped from a bubble under
  the floor can become stuck; if the rest of the party joins them there, the
  level softlocks until the level timer expires.
- Why it's still here: this project deliberately targets PAL revision 0
  (`SMNP01`), not revision 2, because the public decomp and symbol maps
  (NSMBW-Decomp, NSMBW-Maps, RootCubed's cracked symbol table) target
  revision 0. The revision-2 collision fix is not ported. See
  `docs/NSMBW-PLAN.md` §2.1.1 for the full reasoning.
- If a tester hits this: it reproduces on real rev 0 hardware/Dolphin too.
  It is not evidence of a translation bug — do not spend time bisecting
  translated code against it.
- Disposition: faithful-to-rev-0 is the standard here. Revisiting the
  revision-2 collision fix as an optional post-v1 patch stays available but
  is explicitly out of scope and off the critical path.
