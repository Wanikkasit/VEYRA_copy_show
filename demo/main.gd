extends Control
## Limited VEYRA portfolio slice: mobile UI, offline state and demonstration flows.
const Rules = preload("res://demo_rules.gd")
const Portrait = preload("res://portrait_preview.gd")
const SAVE_PATH := "user://veyra_portfolio_slice_v02.json"
const BG := Color("#0e1825")
const PANEL := Color("#1d3040")
const GOLD := Color("#ebca8d")
const SOFT := Color("#d5dfe2")
const MUTED := Color("#9bb2bf")
var rng := RandomNumberGenerator.new()
var state: Dictionary = {}
var gender: String = "Woman"
var hair: int = 0
var skin: int = 1
var page: String = "Life"
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
    for side in ["left", "right", "top", "bottom"]:
        margins.add_theme_constant_override("margin_" + side, 20 if side != "top" else 30)
    margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(margins)
    screen = VBoxContainer.new()
    screen.add_theme_constant_override("separation", 13)
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

func _label(message: String, points: int = 23, tint: Color = SOFT, parent: Node = null) -> Label:
    var lbl := Label.new()
    lbl.text = message
    lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    lbl.add_theme_font_size_override("font_size", points)
    lbl.add_theme_color_override("font_color", tint)
    lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    if parent == null:
        screen.add_child(lbl)
    else:
        parent.add_child(lbl)
    return lbl

func _button(title: String, action: Callable, enabled: bool = true, parent: Node = null, subtle: bool = false) -> Button:
    var b := Button.new()
    b.text = title
    b.custom_minimum_size = Vector2(0, 64)
    b.disabled = not enabled
    b.add_theme_font_size_override("font_size", 21)
    b.add_theme_color_override("font_color", SOFT)
    b.add_theme_color_override("font_disabled_color", MUTED.darkened(0.35))
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("#253a49") if subtle else Color("#365765")
    if not enabled:
        normal.bg_color = Color("#1a2a35")
    for side in ["top_left", "top_right", "bottom_left", "bottom_right"]:
        normal.set("corner_radius_" + side, 10)
    normal.content_margin_left = 10
    normal.content_margin_right = 10
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", normal)
    b.add_theme_stylebox_override("pressed", normal)
    b.add_theme_stylebox_override("disabled", normal)
    b.pressed.connect(action)
    if parent == null:
        screen.add_child(b)
    else:
        parent.add_child(b)
    return b

func _card() -> VBoxContainer:
    var panel := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = PANEL
    style.set_corner_radius_all(12)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 14
    style.content_margin_bottom = 14
    panel.add_theme_stylebox_override("panel", style)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    screen.add_child(panel)
    var inside := VBoxContainer.new()
    inside.add_theme_constant_override("separation", 11)
    panel.add_child(inside)
    return inside

func _portrait() -> void:
    var portrait: Control = Portrait.new()
    portrait.gender = gender
    portrait.hair = hair
    portrait.skin = skin
    portrait.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    portrait.custom_minimum_size = Vector2(0, 265)
    screen.add_child(portrait)

func _header() -> void:
    _label("VEYRA", 46, GOLD)
    _label("YOUR LIFE. YOUR CHOICES.    •    LIMITED DEMO", 17, MUTED)

func _show_intro() -> void:
    _clear()
    _header()
    _label("A fantasy life from childhood to legacy.", 23)
    _portrait()
    _label("Appearance", 28, GOLD)
    var hair_labels: Array = ["Onyx Layered", "Chestnut Sidecut", "Golden Parted", "Silver Flow"]
    _label("%s  •  %s  •  Skin %d/3" % [gender, hair_labels[hair], skin + 1], 20)
    var selectors := HBoxContainer.new()
    selectors.add_theme_constant_override("separation", 9)
    screen.add_child(selectors)
    _button("Character", func() -> void:
        gender = "Man" if gender == "Woman" else "Woman"
        _show_intro(), true, selectors, true)
    _button("Hair", func() -> void:
        hair = (hair + 1) % 4
        _show_intro(), true, selectors, true)
    _button("Skin", func() -> void:
        skin = (skin + 1) % 3
        _show_intro(), true, selectors, true)
    _button("BEGIN LIFE", func() -> void:
        state = Rules.create_life(gender, hair, rng.randi(), skin)
        _save_state()
        page = "Life"
        _show_game())
    _label("Original demo artwork • The private game uses a larger modular pixel-art catalog.", 17, MUTED)

func _show_game() -> void:
    _clear()
    state = Rules.normalize(state)
    gender = str(state.get("gender", "Woman"))
    hair = int(state.get("hair", 0))
    skin = int(state.get("skin", 1))
    _header()
    _label("%s  •  Age %d  •  %s" % [str(state.get("name", "Traveler")), int(state.get("age", 0)), Rules.stage_for_age(int(state.get("age", 0)))], 27, GOLD)
    var nav := HBoxContainer.new()
    nav.add_theme_constant_override("separation", 8)
    screen.add_child(nav)
    for tab in ["Life", "People", "Activities", "Bag"]:
        var selected_tab: String = tab
        var tab_button := _button(tab, func() -> void:
            page = selected_tab
            _show_game(), true, nav, page != tab)
        tab_button.add_theme_font_size_override("font_size", 17)
        tab_button.custom_minimum_size.y = 52
    if page == "People":
        _show_people()
    elif page == "Activities":
        _show_activities()
    elif page == "Bag":
        _show_bag()
    else:
        _show_life()
    _label("Offline • local autosave • small standalone showcase, not the full game.", 16, MUTED)

func _show_stats() -> void:
    var stats := _card()
    _label("Health %d / 100    •    Coins %d" % [int(state.get("health", 100)), int(state.get("coins", 0))], 22, GOLD, stats)
    _label("Renown %d    •    Family bonds %d" % [int(state.get("renown", 0)), int(state.get("bond", 0))], 19, SOFT, stats)
    _label("Element: %s    •    Talent: %s" % [str(state.get("element", "")), str(state.get("talent", ""))], 18, MUTED, stats)

func _show_life() -> void:
    _portrait()
    _show_stats()
    if str(state.get("last_result", "")) != "":
        _label(str(state["last_result"]), 20, GOLD)
    if bool(state.get("ended", false)):
        _label("THE END OF THIS LIFE", 32, GOLD)
        _button("BEGIN A NEW LIFE", func() -> void:
            state = {}
            _save_state()
            _show_intro())
        return
    var event: Dictionary = Rules.event_for_age(int(state["age"]), int(state["year"]), state)
    var box := _card()
    _label("YEAR %d    •    %s" % [int(state["year"]), str(event["title"])], 25, GOLD, box)
    _label(str(event["story"]), 21, SOFT, box)
    if not bool(state.get("acted", false)):
        var choices: Array = Rules.available_choices(state, event)
        for i in range(choices.size()):
            var choice_idx: int = i
            var choice: Dictionary = choices[i]
            _button("%d. %s" % [i + 1, str(choice["text"])], func() -> void:
                _choose(choice_idx), true, box)
    else:
        _label("Decision made. You can visit other tabs before advancing.", 19, MUTED, box)
        _button("ADVANCE ONE YEAR", func() -> void:
            state = Rules.advance_year(state)
            _save_state()
            _show_game(), true, box)
    if int(state["age"]) < 16:
        _button("Preview adulthood (skip to age 16)", func() -> void:
            state = Rules.skip_to_adult(state)
            _save_state()
            _show_game(), true, screen, true)

func _show_people() -> void:
    _label("PEOPLE & FAMILY", 29, GOLD)
    var box := _card()
    _label("Rowan  •  Childhood friend", 24, GOLD, box)
    _label("Friendship %d    •    Family bonds %d" % [int(state.get("friendship", 0)), int(state.get("bond", 0))], 21, SOFT, box)
    _label("Relationships can grow through choices and time spent together.", 19, MUTED, box)
    _button("Spend time with Rowan (once/year)", func() -> void:
        state = Rules.spend_time(state)
        _save_state()
        _show_game(), not bool(state.get("social_used", false)) and not bool(state.get("ended", false)), box)
    var history: Array = state.get("history", [])
    _label("YOUR CHRONICLE", 26, GOLD)
    if history.is_empty():
        _label("Your story is only beginning.", 20, MUTED)
    else:
        var logbox := _card()
        for entry in history.slice(0, 6):
            _label("• " + str(entry), 18, SOFT, logbox)

func _show_activities() -> void:
    _label("ACTIVITIES & PATHS", 29, GOLD)
    var box := _card()
    _label("Knowledge %d    •    Strength %d    •    Craft %d" % [int(state["knowledge"]), int(state["strength"]), int(state["craft"])], 19, GOLD, box)
    _label("Choose one activity per year. Events and social time are separate.", 19, MUTED, box)
    for work in Rules.ACTIVITIES:
        var activity_name: String = work
        _button(work, func() -> void:
            state = Rules.activity(state, activity_name)
            _save_state()
            _show_game(), not bool(state.get("activity_used", false)) and not bool(state.get("ended", false)), box)
    _label("YOUR CAREER", 26, GOLD)
    var career_box := _card()
    _label(str(state.get("career", "Undecided")), 23, GOLD, career_box)
    if int(state.get("age", 0)) < 16:
        _label("Choose a path from age 16.", 19, MUTED, career_box)
    elif str(state.get("career", "Undecided")) == "Undecided":
        for role in Rules.CAREERS:
            var role_name: String = role
            _button(role, func() -> void:
                state = Rules.choose_career(state, role_name)
                _save_state()
                _show_game(), true, career_box)
    else:
        _label("Career path selected for this limited lifetime demo.", 18, MUTED, career_box)

func _show_bag() -> void:
    _label("INVENTORY & MARKET", 29, GOLD)
    _label("Coins %d" % int(state.get("coins", 0)), 23, GOLD)
    var box := _card()
    var bag: Array = state.get("bag", [])
    for item in bag:
        _label("• " + str(item), 21, SOFT, box)
    _label("SMALL MARKET", 26, GOLD)
    var shop := _card()
    for item in Rules.ITEMS.keys():
        var item_name: String = str(item)
        var cost: int = int(Rules.ITEMS[item_name])
        _button("%s  •  %d coins" % [item_name, cost], func() -> void:
            state = Rules.buy_item(state, item_name)
            _save_state()
            _show_game(), int(state.get("coins", 0)) >= cost and not bag.has(item_name) and not bool(state.get("ended", false)), shop)

func _choose(index: int) -> void:
    if bool(state.get("acted", false)) or bool(state.get("ended", false)):
        return
    var event: Dictionary = Rules.event_for_age(int(state["age"]), int(state["year"]), state)
    var options: Array = Rules.available_choices(state, event)
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
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
    if typeof(parsed) != TYPE_DICTIONARY:
        return false
    state = Rules.normalize(parsed)
    return state.has("name") and state.has("age") and state.has("gender")
