# VEYRA — Original Fantasy Life-Sim (Android)

**Public portfolio showcase v0.2** · Godot / GDScript · Offline Android · AI-assisted development

VEYRA is an original, portrait-first fantasy RPG/life simulation. Players are born into a randomized life, grow older and shape their story through choices, relationships and personal development.

**[Download v0.2 Android APK](https://github.com/Wanikkasit/VEYRA_copy_show/releases/tag/portfolio-slice-v0.2)** · **[Playable scope](docs/DEMO_SCOPE.md)** · **[Engineering notes](docs/ENGINEERING_NOTES.md)** · **[CI build](.github/workflows/limited-demo-android.yml)**

> The showcase is a **new, independent subset** based on selected game concepts, NOT the original P92/P93 code or complete game. Original art, private systems and the full 2,227-event library remain private. Character artwork here is an improved demo illustration, not a production game portrait.

## What to try
1. Install the Android debug APK from the v0.2 release.
2. Choose gender, one of four paired hairstyles and skin tone; begin a randomized life.
3. Make an age-based event choice. Check the effect on health, coins, renown, friendship or skills.
4. Open **People** to spend time with Rowan and view the chronicle.
5. Open **Activities** for yearly study/training/work/rest and age-16 career selection.
6. Open **Bag** to buy an item; return to **Life** and advance the year.
7. Test local autosave by closing and reopening the app.

No internet, sign-in, analytics or database account needed. Manual Android-device validation is still required. The build uses a separate v0.2 application ID to avoid replacing v0.1 save data.

## Code worth reviewing
- [Rules and events](demo/demo_rules.gd)
- [Mobile screens](demo/main.gd)
- [Layered illustrated portrait](demo/portrait_preview.gd)
- [Smoke tests](demo/smoke_test.gd)
- [Android build and release](.github/workflows/limited-demo-android.yml)

## My contribution
I define the game design, age progression and UI requirements, use ChatGPT/Codex to support implementation, review and test Android builds, and refine issues from feedback. I am transparent that AI-assisted tools contribute to implementation. The game has no embedded LLM agent.

**Important:** The playable portfolio slice deliberately exposes only representative sample code and assets. See [scope and limitations](docs/DEMO_SCOPE.md). Older [v0.1](https://github.com/Wanikkasit/VEYRA_copy_show/releases/tag/portfolio-slice-v0.1) remains archived and available.
