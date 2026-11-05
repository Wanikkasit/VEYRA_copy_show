# VEYRA — engineering and AI-assisted development

## Product objective
A portrait-first, offline Android fantasy life-simulation prototype where a randomly generated character grows older, meets events and makes decisions. Peaceful choices are valid; combat is not mandatory.

## My work and tools
I defined gameplay constraints, reviewed mobile UI, iterated on character-creation requirements, tested APK builds and documented issues and acceptance criteria. AI coding tools including ChatGPT/Codex assisted with GDScript implementation and CI automation. I do not claim to have independently written the whole game.

## Demonstrable architecture
In this public slice, `demo_rules.gd` is a small pure-rules module. `main.gd` handles UI, state updates and local save/load. `portrait_preview.gd` draws a simplified front-view demonstration figure. This is not a source dump of the private game's more extensive systems.

## Acceptance examples
1. A new life gets one of six elements and a valid talent.
2. A year offers at least two meaningful choices.
3. One decision per year; a second click cannot duplicate its rewards.
4. Age advancement is blocked until a decision is made.
5. Closing and reopening the Android app should reload the saved state.
6. A life ends at age 85, or when health reaches zero.
7. No network connection, login or access to the private repository is required.

The CI workflow checks the GDScript rules in headless Godot and tries an Android debug export. A successful CI build is not equivalent to on-device functional testing; install and verify the resulting APK on a real phone before promoting it as a tested public release.
