# VEYRA — Authentic P89 Limited Android Showcase

This APK is built from the verified, original VEYRA P89 Godot game source, not from the separately implemented v0.1/v0.2 demonstration project.

## Included
- Actual original game UI and core gameplay from a copied P89 verified-source archive.
- Original modular 160x176 pixel character portraits and portrait compositor.
- 348 **unchanged, original** authored event objects, selected from the 2,227 original events with scheduled-event dependencies retained.
- Visible: Life, Career, Character, Family, Friends, People, Inventory & Crafting, Chronicle.
- Navigation disabled/redirected for Adventure, Combat, World and the internal Test Guide.
- Offline Android game, different Android package ID to avoid overwriting previous game installs.

## Verification and limits
- Godot 4.7.2 import/boot passed with 348 events.
- Focused smoke check rendered an authentic 160x176 character portrait from original layers.
- Android APK exported and signed; APK signature v2/v3 validation and archive integrity passed.
- No manual physical-device playthrough is claimed.
- The original full-game 2,227-event regression suite is not applicable to a 348-event subset and was **not** a passing validation gate for this limited build.
- APK resources can be inspected/reverse engineered. This is a **limited UI/content exposure**, not a guarantee that all private code is cryptographically hidden.

## Source
- Source samples in the separate ZIP are selected genuine P89 GDScripts and the exact limited UI patch, **not a complete buildable repository**.
- The original private repository was not edited or made public.
- P89 verified-source archive SHA-256: cb59abe0f81fff01309d8820cffddee6d14c9c27f0cf039d3a96bd169785bf8a
- This restricted APK SHA-256: 022076a4fd1058aafa45a3a11be32b61e6604b8a9eec11b5b811d728fea9ba02
- Android package: org.veyra.originalshowcase.p89

Important: Old public v0.1/v0.2 demonstration APKs are independently implemented and should not be represented as this real P89 build.