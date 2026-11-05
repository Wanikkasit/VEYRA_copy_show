# VEYRA

Android fantasy life RPG prototype by **Wanikkasit Nopthiraitthikun**.

A personal project developed with ChatGPT/Codex assistance. This portfolio shows a playable Android build, a small source excerpt and the way I work with requirements and testing.

**[Download the Android APK](https://github.com/Wanikkasit/VEYRA_copy_show/releases/download/portfolio-p92/VEYRA-P92-demo.apk)** · **[Installation and five-minute demo](docs/TRY_THE_DEMO.md)** · **[My contribution](docs/CASE_STUDY.md)**

The download is the existing P92 prototype, approximately **33 MB**, for **64-bit Android (arm64-v8a)**. It is an evaluation build with known limitations. The full development repository remains private.

## What to try

- Create a character and change the portrait options.
- Start a life and explore the age-based actions and event choices.
- Visit Character, Family or People to inspect the information shown.
- Use available actions, then finish the year when the interface allows it.
- Close and reopen the app to check that the same life continues.

Age and state affect which actions are available. A short session does not demonstrate every planned feature or the full generational design.

## Portrait preview

These are two compositions of the actual portrait layers shipped in P92, enlarged with nearest-neighbour scaling. They are asset previews, not screenshots of an Android device.

| Woman portrait | Man portrait |
|---|---|
| ![Woman portrait composed from P92 layers](media/portrait-woman.png) | ![Man portrait composed from P92 layers](media/portrait-man.png) |

One hairstyle option selects a matching front/back pair. This keeps the mobile controls compact while the renderer combines several layers internally.

## Engineering example

[The selected GDScript excerpt](samples/portrait_eligibility.gd) checks whether an important-NPC portrait asset is eligible for a given age, role and personality. Only this small rule is included; the complete catalog and game systems are private.

See the [case study](docs/CASE_STUDY.md) for requirements, an iteration example and my contribution, and [validation notes](docs/VALIDATION.md) for the limits of the evidence.

## My role and AI assistance

I defined gameplay and mobile UI requirements, requested iterative changes with ChatGPT/Codex, tested Android builds and reported problems. AI coding tools assisted with implementation and technical checks. I do not claim to have written every part independently.

This is an example of **building with AI coding tools**. The showcase does not claim that the game contains an LLM agent or that I built a multi-agent system.

## What this repository contains

- The APK download and installation guide.
- Two selected portrait previews.
- A short GDScript example and product/testing notes.
- Public delivery scripts that verify and publish the APK.

The original source archive, full development history, internal roadmap, editable artwork and complete game source are not published as repository source. The APK necessarily contains the compiled game and runtime resources needed to play; those can be inspected or extracted. This is not a content-limited or tamper-proof build.

The files under `.delivery/` are encoded copies of the same APK for automated distribution. Recruiters can use the direct APK link above; no reconstruction or GitHub Actions access is needed.

## Technology and status

Godot 4.7.2 · GDScript · Android · JSON content · GitHub Actions

**Status:** personal prototype in development. P92 includes portrait-quality changes and compatibility handling for old appearance IDs. Some art and gameplay still need refinement. See [known limitations](docs/TRY_THE_DEMO.md#known-limitations) before evaluating.

This public showcase is for portfolio review, rather than an open-source release of the full game. Godot's engine license and third-party notices retain their own terms: [Godot license](https://godotengine.org/license/).
