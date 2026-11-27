# One Night — Nov 28 viability playtest

## Verified baseline (Nov 27)
- Main: 1ba34584ffaf55adfdb70b440c2cbf5905ebb9d0, first-person hook presentation polish.
- APK release version.json returned code 202, sha 1ba3458. [Android APK](https://github.com/duffpowell-commits/lethemoor/releases/download/dev/lethemoor.apk).
- [Web build](https://duffpowell-commits.github.io/lethemoor/): version.json at the site root returned 404; verify displayed build in-game before collecting results.
- STATUS reports 85 headless tests passed for hook polish. Not independently rerun in this review; GitHub connector returned no combined statuses or PR-triggered runs for this main commit. No new runtime or device measurements.
- Previous blind score: 6.4/10 on build 196; build 199 and 202 not scored here. Blind reviews remain paused.

## Phone test (one row per tester)
Play without coaching; retain first-run impressions. Record actual displayed build, device, platform, FPS shown in MENU during exploration and a horror encounter, fun 1–10, and whether the tester chooses another night unprompted. Note whether they understood oil, bell direction, hook feedback, sound/captions, swipe controls, and what killed them. Record completed or died, oil remaining, and any crashes.

| Tester ID | Build | Device/platform | Fun /10 | Voluntary replay? | FPS typical/low | Confusion or bugs |
|---|---|---|---|---|---|---|
| | | | | | | |

Viability: median fun >= 6/10 and testers choose to replay. Report numerator/denominator, median, and observations separately; do not invent results or an arbitrary replay threshold. Release quality is separate (studio target 9/10, historical slice review target 8.5). If viability is not demonstrated, keep full-game systems parked.

## Atmosphere handoff
PR #74 describes the seven-beat presentation pass. Begin after baseline human evidence: existing harbor, original ambient audio and captions, wall coping, rare cosmetic reflection/return-visit events, letters, seeded variation independent of simulation RNG, dawn verdict polish. First fix P0 wall tops using matching painted source; preserve faceless rigs and compatibility renderer. PR #73 is a test-only Thrall candidate with deformation failure; retain the current rig. Do not change mechanics or publish a replacement asset prematurely. Compare before/after engine captures, test reduced effects and phone readability, run tests and parse check, ART PASS and required CI/fresh-eyes checks. Log evidence and remaining gaps before any merge.

No code or art changed in this baseline review. Human phone evidence remains outstanding.
