# VEYRA — Authentic Android Fantasy Life Simulator

**Original game code · Godot / GDScript · Android · P89 restricted portfolio build**

> This release uses the **actual VEYRA P89 game**, not the independently rewritten v0.1/v0.2 samples. It is a limited feature/content showcase built from a copy of the private original. The original private repository is not changed.

## Download and play

**[Download VEYRA P89 — Real-game limited Android APK](https://github.com/Wanikkasit/VEYRA_copy_show/releases/download/authentic-p89-limited-20261105/VEYRA-P89-Authentic-Limited-Showcase.apk)**

[Release notes and APK details](https://github.com/Wanikkasit/VEYRA_copy_show/releases/tag/authentic-p89-limited-20261105) · [Successful GitHub build and verification](https://github.com/Wanikkasit/VEYRA_copy_show/actions/runs/42069041867)

- APK: `VEYRA-P89-Authentic-Limited-Showcase.apk` (32,479,415 bytes)
- SHA-256: `022076a4fd1058aafa45a3a11be32b61e6604b8a9eec11b5b811d728fea9ba02`
- Package: `org.veyra.originalshowcase.p89` (distinct from prior demo installs)
- Offline, Android debug build; no cloud sign-in required

## What is included

- Existing VEYRA Life, Career, Character, Family, Friends, People, Inventory & Crafting, and Chronicle views.
- Existing portrait-first mobile UI and **original 160 × 176 modular pixel portraits**, not replacement procedural portraits.
- **348 unchanged original authored events**, selected from the full 2,227-event P89 library, preserving chained-event dependencies.
- Original event, progression, career, family, relationship, inventory, saved-state and portrait systems rather than a newly implemented demo game.

**Intentionally limited navigation:** Adventure, Combat, World and the internal Test Guide menu are hidden/redirected in this APK. This is a UI/content limitation, not a cryptographic protection scheme: Android binaries are inspectable.

## Review the actual code

The following files are selected **unaltered extracts from P89 original gameplay source**. They are provided for code review, not as a complete, independently buildable Godot project.

- [Original event database and director](authentic_p89/source/core/events/)
- [Original career system](authentic_p89/source/core/career/career_system.gd)
- [Original family system](authentic_p89/source/core/family/family_system.gd)
- [Original relationship utilities](authentic_p89/source/core/relationship/relationship_utils.gd)
- [Original portrait compositor and catalog](authentic_p89/source/ui/widgets/)
- [P89 original UI integration patches](authentic_p89/patches/)
- [Exactly what changed for the restricted version](authentic_p89/docs/REAL_SOURCE_UI_CHANGES.patch)
- [Original-source showcase smoke test](authentic_p89/tests/portfolio_limited_smoke.gd)
- [Provenance and validation details](authentic_p89/README.md)

### Reproducible release packaging

The [GitHub Actions workflow](.github/workflows/authentic-p89-release.yml) reconstructs the **byte-identical, previously signed authentic restricted P89 APK** using a verified base Android engine from the old demo and the changed original P89 content held in [APK delta parts](authentic_p89/apk_patch/). The base demo is used **only for unchanged Android/Godot binary streams**; gameplay, UI, art and event content in the resulting APK are from original P89. Its SHA-256 is verified before publishing. This is packaging of an existing authentic build, **not recompilation from these public source extracts**.

### Tests and limitations

GitHub verification confirms the reconstructed signed APK is byte-identical to the local restricted P89 build, loads 348 events, contains original Godot portrait code, and has valid ZIP integrity. Earlier local testing included Godot import/boot, a focused original portrait render smoke check, and APK signature verification. **Installation and gameplay on a physical Android phone have not been independently confirmed for this restricted APK.**

## My contribution

I define and review original game requirements, gameplay and portrait UI, use ChatGPT/Codex to assist implementation, inspect Android builds, report bugs and refine game requirements. This original game is AI-assisted work; it is not presented as a hand-coded AI agent.

## Archived demonstrations

Earlier [v0.1 and v0.2 releases](https://github.com/Wanikkasit/VEYRA_copy_show/releases) were separately reimplemented examples and are **not the original game**. They are retained for historical transparency. For an authentic VEYRA evaluation, use the **P89 download above**.
