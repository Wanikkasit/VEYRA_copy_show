# VEYRA — Android Fantasy Life-Sim
**Playable portfolio slice · Godot / GDScript · Android · Offline**

VEYRA is an original, portrait-first fantasy life-simulation/RPG concept: start a randomly generated life, grow older, respond to events, and shape a story through choices. Combat is optional in the wider game concept; peaceful lives matter too.

**[Download playable Android APK (28 MB)](https://github.com/Wanikkasit/VEYRA_copy_show/releases/download/portfolio-slice-v0.1/VEYRA-Limited-Demo.apk)** · **[Release & checksum](https://github.com/Wanikkasit/VEYRA_copy_show/releases/tag/portfolio-slice-v0.1)** · **[What's playable](docs/DEMO_SCOPE.md)** · **[Engineering and testing](docs/ENGINEERING_NOTES.md)**

[![Android demo build](https://github.com/Wanikkasit/VEYRA_copy_show/actions/workflows/limited-demo-android.yml/badge.svg)](https://github.com/Wanikkasit/VEYRA_copy_show/actions/workflows/limited-demo-android.yml)

> **Important:** This repository contains a **small, separate playable portfolio demonstration**, not the complete VEYRA game or the old P92 APK. This is intentional: the full source, art archive, events and complex systems are private. The limited demo source is public so a reviewer can inspect representative implementation and run an Android build.

## Try the demo (about five minutes)

1. Open [Releases](https://github.com/Wanikkasit/VEYRA_copy_show/releases/latest) and download **VEYRA-Limited-Demo.apk** when the Android build has passed.
2. Install the APK on a 64-bit Android phone (allow installation from your browser/files app if Android prompts you).
3. Pick a character presentation and hairstyle, then press **BEGIN LIFE**.
4. Make an event choice and press **ADVANCE ONE YEAR**. Observe your changing health, coins, bonds and renown.
5. Use **Skip to age 16 (demo shortcut)** to see adult events; close and reopen the app to test local autosave.

No sign-in, internet or backend account is required. It is a debug-signed prototype, not a Play Store release. **Android installation and behavior on every device have not yet been independently verified.**

## Included / excluded

| Included in this public demonstration | Kept private |
| --- | --- |
| Random life, gender presentation, simplified portrait | Actual P92 modular portrait art, full asset catalog |
| Six elements and aptitude | Full world simulation and complete gameplay systems |
| Age-gated event choices and year progression | 2,227-event narrative catalog and long-form stories |
| Simplified currency, health, bonds, renown, autosave | Original save schema, AI-assisted iteration history, original private repository |
| Small GDScript rule engine and Android CI | Full original code and production game design documents |

This limited slice is **not marketed as feature-complete**, and its simplified portrait is not a screenshot of P92. See the detailed [scope and security disclosure](docs/DEMO_SCOPE.md).

## Source code worth reviewing

- [`demo/demo_rules.gd`](demo/demo_rules.gd): example life creation, age-based events, constrained choices and state transitions.
- [`demo/main.gd`](demo/main.gd): mobile UI, choice navigation and offline autosave.
- [`demo/smoke_test.gd`](demo/smoke_test.gd): regression checks for core invariants.
- [Android build workflow](.github/workflows/limited-demo-android.yml): automated export, smoke checks, APK integrity check and release.

This is a separate implementation of a selected game loop rather than the proprietary main game's source tree. A limited APK can still be unpacked or reverse engineered; the protection is that it **does not contain the private game's full content or implementation**.

## My contribution and use of AI coding tools

I defined the game concept and functional constraints, requested and reviewed UI/gameplay iterations, tested Android builds, documented issues, and made product decisions based on feedback. ChatGPT/Codex assisted with programming, debugging, test scripts and automation. **I do not claim to have manually authored every line of code.**

This portfolio demonstrates practical **AI-assisted product engineering**, not an embedded LLM agent inside the game.

## Project status

Personal prototype / limited Android demonstration. The complete VEYRA project remains under development. The GitHub Actions run determines whether the downloadable APK has been produced successfully; please check the release and its SHA-256 checksum rather than relying on the README alone.

*Copyright © VEYRA creator. The Godot engine and third-party components retain their own licenses. Public visibility of source files here is not permission to redistribute the full VEYRA concept or private assets.*
