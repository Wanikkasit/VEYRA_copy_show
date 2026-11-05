# VEYRA portfolio — engineering notes

Original VEYRA is a private portrait-first life-sim project. Its development includes P92 character-art quality controls, age-based progression, narrative events, social/family systems and later P93 optional scene illustrations. **This public v0.2 is an independently written, limited showcase** informed by that project's requirements, not a dump of its original files.

## What a reviewer can inspect
- `demo/demo_rules.gd`: isolated, deterministic event pools by age; skill, relationship and economic state changes; decisions cannot be applied twice per year; separate social and activity quotas; one career choice from age 16; guardrails for purchasing and age advancement.
- `demo/main.gd`: one-column portrait mobile UI with Life, People, Activities and Bag screens; local JSON autosave; state normalization on load.
- `demo/portrait_preview.gd`: independently authored more detailed layered character illustration; paired front/back hair concepts and fixed appearance palettes. Not the production P92 pixel sprites.
- `demo/smoke_test.gd`: headless regression checks for rule invariants.
- `limited-demo-android.yml`: Android debug export and integrity validation.

## My role and use of AI
The creator defines VEYRA's gameplay direction, product constraints, mobile usability feedback and acceptance requirements, tries APKs and reports issues. ChatGPT/Codex supports coding, debugging, tests and CI scripts. Do not attribute every implementation line to manual authoring.

## Boundaries
This demo does **not** implement a real LLM or autonomous agent inside the game. Its limited rules, friendly NPC and store are intentionally illustrative rather than faithful copies of P92's simulation. Successful CI output is not equivalent to a successful install and playthrough on a physical Android device. Previous v0.1 release remains available.
