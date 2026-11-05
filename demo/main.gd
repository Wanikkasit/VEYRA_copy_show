extends Control
## Minimal offline product slice. This is not the original private VEYRA game.
const Rules = preload("res://demo_rules.gd")
const Portrait = preload("res://portrait_preview.gd")
const SAVE_PATH := "user://veyra_portfolio_slice.json"
const BG := Color("#0d1423")
const PANEL := Color("#1b2a40")
const GOLD := Color("#dfc28e")
const SOFT := Color("#bdcadb")
var rng := RandomNumberGenerator.new()
var state: Dictionary = {}
var gender: String = "Woman"
var hair: int = 0
var screen: VBoxContainer

func _ready() -> void:
    rng.randomize()
    var bg := ColorRect.new()
    bg.color = BG
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(bg)
    var scroll := ScrollContainer.new()
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(scroll)
    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 26)
    margins.add_theme_constant_override("margin_right", 26)
    margins.add_theme_constant_override("margin_top", 32)
    margins.add_theme_constant_override("margin_bottom", 32)
    margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(margins)
    screen = VBoxContainer.new()
    screen.add_theme_constant_override("separation", 17)
    screen.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margins.add_child(screen)
    if _load_state():
        _show_game()
    else:
        _show_intro()

func _clear() -> void:
    for child in screen.get_children():
        screen.remove_child(child)
        child.queue_free()

func _label(message: String, points: int = 26, tint: Color = SOFT) -> void:
    var lbl := Label.new()
    lbl.text = message
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lbl.add_theme_font_size_override("font_size", points)
    lbl.add_theme_color_override("font_color", tint)
    screen.add_child(lbl)

func _button(title: String, action: Callable, enabled: bool = true) -> void:
    var b := Button.new()
    b.text = title
    b.custom_minimum_size = Vector2(0, 70)
    b.disabled = not enabled
    b.add_theme_font_size_override("font_size", 23)
    b.add_theme_color_override("font_color", Color("#f4f6fb"))
    b.add_theme_color_override("font_hover_color", Color("#ffffff"))
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#324b69") if enabled else Color("#293443")
    normal.corner_radius_top_left = 12
    normal.corner_radius_top_right = 12
    normal.corner_radius_bottom_left = 12
    normal.corner_radius_bottom_right = 12
    normal.content_margin_left = 13.0
    normal.content_margin_right = 13.0
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("disabled", normal)
    b.pressed.connect(action)
    screen.add_child(b)

func _portrait() -> void:
    var pic: Control = Portrait.new()
    pic.gender = gender
    pic.hair = hair
    screen.add_child(pic)

func _show_intro() -> void:
    _clear()
    _label("VEYRA", 52, GOLD)
    _label("FANTASY LIFE SIM • PORTFOLIO SLICE", 21)
    _label("Choose a character, live through events and discover how each year changes your story.", 24)
    _portrait()
    _label("Character: " + gender + "    •    Hair: " + ["Dark", "Chestnut", "Silver"][hair], 22, GOLD)
    _button("Change Character", func() -> void:
        gender = "Man" if gender == "Woman" else "Woman"
        _show_intro()
    )
    _button("Change Hair", func() -> void:
        hair = (hair + 1) % 3
        _show_intro()
    )
    _button("BEGIN LIFE", func() -> void:
        state = Rules.create_life(gender, hair, rng.randi())
        _save_state()
        _show_game()
    )
    _label("Demo limitation: only a few events and three illustrated hairstyles. The full game is private.", 19)

func _show_game() -> void:
    _clear()
    gender = str(state.get("gender", "Woman"))
    hair = int(state.get("hair", 0))
    _label("VEYRA / YOUR LIFE", 37, GOLD)
    _portrait()
    _label(str(state.get("name", "Traveler")) + "    •    Age " + str(state.get("age", 0)), 30, GOLD)
    _label("Element: " + str(state.get("element", "Earth")) + "    |    Talent: " + str(state.get("talent", "Trade")), 22)
    _label("Health " + str(state.get("health", 100)) + "    Coins " + str(state.get("coins", 0)), 22)
    _label("Renown " + str(state.get("renown", 0)) + "    Bonds " + str(state.get("bond", 0)), 22)
    if str(state.get("last_result", "")) != "":
        _label(str(state["last_result"]), 20, GOLD)
    if bool(state.get("ended", false)):
        _label("THE END OF THIS LIFE", 31, GOLD)
        _button("BEGIN A NEW LIFE", func() -> void:
            state = {}
            _save_state()
            _show_intro()
        )
        return
    var event: Dictionary = Rules.event_for_age(int(state.get("age", 0)), int(state.get("year", 1)))
    _label("YEAR " + str(state.get("year", 1)) + "  /  " + str(event["title"]), 29, GOLD)
    _label(str(event["story"]), 24)
    if not bool(state.get("acted", false)):
        var choices: Array = event["choices"]
        for i in range(choices.size()):
            var choice_idx: int = i
            var choice: Dictionary = choices[i]
            _button(str(choice["text"]), func() -> void: _choose(choice_idx))
    else:
        _label("This year's decision is complete. Continue to see what comes next.", 21)
        _button("ADVANCE ONE YEAR", func() -> void:
            state = Rules.advance_year(state)
            _save_state()
            _show_game()
        )
    if int(state.get("age", 0)) < 16:
        _button("Skip to age 16 (demo shortcut)", func() -> void:
            state["age"] = 16
            state["year"] = 17
            state["acted"] = false
            state["last_result"] = "Demo shortcut used to explore adult events."
            _save_state()
            _show_game()
        )
    _label("Auto-saves locally. Offline demo • No account required.", 19)

func _choose(index: int) -> void:
    if bool(state.get("acted", false)) or bool(state.get("ended", false)):
        return
    var event: Dictionary = Rules.event_for_age(int(state["age"]), int(state["year"]))
    var options: Array = event["choices"]
    if index < 0 or index >= options.size():
        return
    state = Rules.apply_choice(state, options[index])
    _save_state()
    _show_game()

func _save_state() -> void:
    var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if file != null:
        file.store_string(JSON.stringify(state))
        file.close()

func _load_state() -> bool:
    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var raw := FileAccess.get_file_as_string(SAVE_PATH)
    var parsed: Variant = JSON.parse_string(raw)
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    state = parsed
    return state.has("name") and state.has("age") and state.has("gender")
