# Authentic VEYRA P89 — Source Provenance and Limited Android Build

This directory records a **real P89 development source** copied from the original private `Wanikkasit/Project-VEYRA`. It is not the separately invented v0.1/v0.2 demo code.

## Verified provenance
- Original private source build: P89 verified source archive from GitHub Actions run `37596893842`.
- SHA-256 of original full P89 source archive: `cb59abe0f81fff01309d8820cffddee6d14c9c27f0cf039d3a96bd169785bf8a`.
- `patches/apply_p89.py` and `patches/finalize_mobile_routing.py` are **verbatim original P89 development scripts**, preserved from the original private repository; the code is not AI-reimplemented for this copy.
- This is a public **review subset**; it is not the complete buildable private source tree.

## The authentic Android showcase APK
A separate Android APK has been built from a **copied original P89 Godot project**, not from the independent demo project. It limits navigation and reduces the actual authored event catalog from 2,227 events to 348 existing original events. It retains the actual Godot character portrait compositor (native 160 x 176 layered art) and original gameplay services.

Build package: `org.veyra.originalshowcase.p89`, version `0.9.0-original-showcase`. APK SHA-256: `022076a4fd1058aafa45a3a11be32b61e6604b8a9eec11b5b811d728fea9ba02` (32,479,415 bytes).

**Distribution status:** The APK was built and validated locally, but **has not been uploaded to this GitHub repository or published as a GitHub Release**. Do not misrepresent legacy v0.1/v0.2 releases as an authentic P89 build. The owner must publish the verified APK asset before the repository is offered as a direct recruiter download link.

## Navigation and data changes for the limited copy
- Retained: Life, Career, Character, Family, Friends, People, Inventory & Crafting, Chronicle.
- Hidden/redirected: Adventure, Combat, World, internal Test Guide.
- Event catalog reduced to 348 **unchanged authored P89 event objects**, with transitive `schedule_event` references preserved.
- Source project display name and Android package ID changed to keep the separate copy independent from the original game.
- Production GDScript game systems, core event processing, saved-state architecture and modular portrait rendering are used as-is in the APK. No substitute game loop was authored.

## Tests performed
- Godot 4.7.2 project opened with 348 events.
- Authentic character compositor produced a 160 x 176 texture in a focused headless smoke test.
- Android debug export completed, Android signature verification passed for APK v2 and v3, and ZIP structure validated.
- On-device Android gameplay/installation was not performed.
- The **original full P89 regression suite is not a passing limited-demo test**, because it explicitly requires the full 2,227-event catalog. Do not cite it as passing after event reduction.
- An Android APK can be inspected and reverse engineered; disabling UI tabs does not make all private implementation details confidential. Review exposure carefully before public release.

## Source policy
The complete original `Project-VEYRA` repository, original full source archive, saved data and full event library remain private. The existing original repository was not edited for this showcase.
