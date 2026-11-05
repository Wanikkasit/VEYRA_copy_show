from pathlib import Path
import re

ROOT = Path("game")

def function_block(text: str, name: str):
    start = text.find(f"func {name}(")
    if start < 0:
        return -1, -1, ""
    nxt = text.find("\nfunc ", start + 1)
    end = nxt if nxt >= 0 else len(text)
    return start, end, text[start:end]

def replace_function(path: Path, name: str, new_block: str):
    text = path.read_text(encoding="utf-8")
    s,e,_ = function_block(text,name)
    if s < 0:
        raise SystemExit(f"P89 missing function {name} in {path}")
    path.write_text(text[:s] + new_block.rstrip() + "\n\n" + text[e+1:], encoding="utf-8")

def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text(encoding="utf-8")
    if old not in text:
        if new in text:
            return
        raise SystemExit(f"P89 missing anchor {label} in {path}")
    path.write_text(text.replace(old,new,1),encoding="utf-8")

# ---------------------------------------------------------------------------
# Portrait widget: render the generated portrait through a real TextureRect.
# The old Control-only custom draw passed headless texture checks but could
# still remain visually blank on device layouts. TextureRect owns visibility;
# _draw now only owns small expression overlays.
# ---------------------------------------------------------------------------
portrait = ROOT / "ui/widgets/portrait_widget.gd"
p = portrait.read_text(encoding="utf-8")
if "var _display: TextureRect" not in p:
    p = p.replace('var _combo_key := ""\n', 'var _combo_key := ""\nvar _display: TextureRect\n', 1)

old_ready = '''func _ready() -> void:
	custom_minimum_size = Vector2(240, 264)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refresh_texture()
'''
new_ready = '''func _ready() -> void:
	custom_minimum_size = Vector2(240, 264)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_display = TextureRect.new()
	_display.name = "PortraitTexture"
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(_display)
	resized.connect(queue_redraw)
	_refresh_texture()
'''
if old_ready in p:
    p=p.replace(old_ready,new_ready,1)

# Synchronize every refresh exit with the visual child.
p=p.replace(
'''\tif not debug_asset_ready():
\t\t_texture = null
\t\treturn
''',
'''\tif not debug_asset_ready():
\t\t_texture = null
\t\t_sync_display_texture()
\t\treturn
''',1)
p=p.replace(
'''\tif layers.is_empty():
\t\t_texture = null
\t\treturn
''',
'''\tif layers.is_empty():
\t\t_texture = null
\t\t_sync_display_texture()
\t\treturn
''',1)
p=p.replace(
'''\tif _variant_cache.has(_combo_key):
\t\t_texture = _variant_cache[_combo_key]
\t\treturn
''',
'''\tif _variant_cache.has(_combo_key):
\t\t_texture = _variant_cache[_combo_key]
\t\t_sync_display_texture()
\t\treturn
''',1)
p=p.replace(
'''\tif image == null:
\t\t_texture = null
\t\treturn
\t_texture = ImageTexture.create_from_image(image)
\t_variant_cache[_combo_key] = _texture
''',
'''\tif image == null:
\t\t_texture = null
\t\t_sync_display_texture()
\t\treturn
\t_texture = ImageTexture.create_from_image(image)
\t_variant_cache[_combo_key] = _texture
\t_sync_display_texture()
''',1)
if "func _sync_display_texture()" not in p:
    anchor='func _compose(layers: Array[Dictionary], important: bool) -> Image:\n'
    helper='''func _sync_display_texture() -> void:
	if _display != null:
		_display.texture = _texture
		_display.visible = _texture != null

'''
    p=p.replace(anchor,helper+anchor,1)

s,e,block=function_block(p,"_draw")
new_draw='''func _draw() -> void:
	if _texture == null:
		_refresh_texture()
	if _texture == null:
		return
	var size: Vector2 = get_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var ratio := float(CELL_SIZE.x) / float(CELL_SIZE.y)
	var width := size.x
	var height := width / ratio
	if height > size.y:
		height = size.y
		width = height * ratio
	var rect := Rect2((size - Vector2(width, height)) * 0.5, Vector2(width, height))
	_draw_expression_overlay(rect)
'''
if s<0: raise SystemExit("P89 portrait _draw missing")
p=p[:s]+new_draw+"\n"+p[e+1:]
portrait.write_text(p,encoding="utf-8")

# ---------------------------------------------------------------------------
# Game: separate yearly actions from social actions and fix childhood actions.
# ---------------------------------------------------------------------------
game = ROOT / "autoload/game.gd"

year_block='''func year_actions_complete() -> bool:
	if not has_active_game():
		return false
	var age := int(player().get("age", 0))
	return int(state.get("calendar", {}).get("turn_in_year", 0)) >= _turns_per_year(age)
'''
social_helpers='''func year_actions_complete() -> bool:
	if not has_active_game():
		return false
	var age := int(player().get("age", 0))
	return int(state.get("calendar", {}).get("turn_in_year", 0)) >= _turns_per_year(age)

func social_actions_per_year() -> int:
	if not has_active_game():
		return 0
	var age := int(player().get("age", 0))
	if age <= 5:
		return 4
	if age <= 17:
		return 4
	return 3

func social_actions_used() -> int:
	if not has_active_game():
		return 0
	return int(state.get("calendar", {}).get("social_actions_used", 0))

func social_actions_remaining() -> int:
	return maxi(0, social_actions_per_year() - social_actions_used())

func social_action_eligibility(target_id: String = "", action_id: String = "") -> Dictionary:
	if not has_active_game():
		return {"available":false,"reason":"Start a life first."}
	if not state.get("active_event", {}).is_empty():
		return {"available":false,"reason":"Resolve the current life event first."}
	if not state.get("combat_state", {}).is_empty() or not state.get("creature_combat_state", {}).is_empty():
		return {"available":false,"reason":"Finish the current encounter first."}
	if not state.get("pending_turn", {}).is_empty():
		return {"available":false,"reason":"Another action is already being resolved."}
	if social_actions_remaining() <= 0:
		return {"available":false,"reason":"No social actions remain this year. Advance the year to refresh them."}
	if not target_id.is_empty():
		var target: Dictionary = state.get("characters", {}).get(target_id, {})
		if target.is_empty() or not bool(target.get("alive", true)):
			return {"available":false,"reason":"That person is not available."}
	var age := int(player().get("age", 0))
	if action_id in ["confess","propose"] and age < 18:
		return {"available":false,"reason":"Romantic commitment actions unlock at age 18."}
	return {"available":true,"reason":""}

func _consume_social_action() -> void:
	if not state.has("calendar") or typeof(state["calendar"]) != TYPE_DICTIONARY:
		state["calendar"] = {}
	state["calendar"]["social_actions_used"] = social_actions_used() + 1
'''
replace_once(game, year_block, social_helpers, "social action budget")

new_activity='''func activity_eligibility(activity: String) -> Dictionary:
	if not has_active_game():
		return {"available": false, "reason": "Start a life first."}
	if activity not in ["play", "study", "train", "work", "family", "socialize", "rest"]:
		return {"available": false, "reason": "That activity is not available."}
	var age := int(player().get("age", 0))
	match activity:
		"play":
			if age > 12:
				return {"available": false, "reason": "Play is a childhood action available through age 12."}
		"study":
			if age < 6:
				return {"available": false, "reason": "Study unlocks at age 6."}
		"train":
			if age < 10:
				return {"available": false, "reason": "Structured training unlocks at age 10."}
		"work":
			if age < 14:
				return {"available": false, "reason": "Work unlocks at age 14. Younger children can Play, spend Family time, or Rest."}
		"socialize":
			return {"available": false, "reason": "Social interactions use separate Social Actions in Friends, Family, and People."}
		"family", "rest":
			pass
	if activity == "work" and age >= 18 and str(player().get("career", "")) == "retired":
		return {"available": false, "reason": "You are retired. Choose a career path if you want to return to work."}
	var legal_key := "family" if activity == "play" else activity
	var legal_access: Dictionary = JusticeSystemClass.restriction(state, legal_key)
	if not bool(legal_access.get("available", false)):
		return legal_access
	if year_actions_complete():
		return {"available": false, "reason": "This year's Year Actions are complete. Social Actions remain separate."}
	if not state.get("active_event", {}).is_empty():
		return {"available": false, "reason": "Resolve the current life event first."}
	if not state.get("combat_state", {}).is_empty() or not state.get("creature_combat_state", {}).is_empty():
		return {"available": false, "reason": "Finish the current encounter first."}
	if not state.get("pending_turn", {}).is_empty():
		return {"available": false, "reason": "Another action is already being resolved."}
	return {"available": true, "reason": ""}
'''
replace_function(game,"activity_eligibility",new_activity)

new_resolve='''func _resolve_pending_turn() -> void:
	var pending: Dictionary = state.get("pending_turn", {})
	if pending.is_empty():
		return
	var activity := str(pending.get("activity", "rest"))
	var social_slot := bool(pending.get("social_action_slot", false))
	state["recent_updates"] = []
	_apply_activity(activity, pending)
	for goal_update in LifeDepthSystemClass.refresh_all_goals(state):
		_append_recent_updates([str(goal_update)])
	if social_slot:
		_consume_social_action()
	else:
		_advance_calendar_and_npcs()
	state["pending_turn"] = {}
	if not bool(player().get("alive", true)):
		_commit("life_ended")
		screen_requested.emit("death")
		return
	var event_instance := EventDirectorClass.select_event(state, activity)
	if not event_instance.is_empty():
		state["active_event"] = event_instance
		_commit("social_event_presented" if social_slot else "event_presented")
		screen_requested.emit("event")
		event_started.emit(event_instance)
	else:
		_commit("social_action_completed" if social_slot else "turn_completed")
		screen_requested.emit("turn_result")
'''
replace_function(game,"_resolve_pending_turn",new_resolve)

new_rel='''func start_relationship_action(target_id: String, social_action: String) -> void:
	if not has_active_game():
		return
	if social_action not in ["play","spend_time","talk","support","confess","propose"]:
		return
	var social_check := social_action_eligibility(target_id, social_action)
	if not bool(social_check.get("available", false)):
		state["recent_updates"] = [str(social_check.get("reason", "That social action is not available."))]
		state_changed.emit()
		return
	var age := int(player().get("age", 0))
	if social_action == "play" and age > 12:
		return
	match social_action:
		"confess":
			if not RomanceSystemClass.can_confess(state, target_id): return
		"propose":
			if not RomanceSystemClass.can_propose(state, target_id): return
	state["pending_turn"] = {
		"activity":"socialize",
		"kind":"relationship",
		"target_id":target_id,
		"social_action":social_action,
		"social_action_slot":true,
		"status":"selected"
	}
	_commit("social_action_selected")
	_resolve_pending_turn()
'''
replace_function(game,"start_relationship_action",new_rel)

# Relationship lifecycle and rivalry also use Social Actions, not Year Actions.
text=game.read_text(encoding="utf-8")
text=text.replace(
'''func start_relationship_lifecycle_action(target_id: String, action_id: String) -> void:
	if not has_active_game() or not state.get("active_event", {}).is_empty() or (not state.get("combat_state", {}).is_empty() or not state.get("creature_combat_state", {}).is_empty()) or not state.get("pending_turn", {}).is_empty():
		return
	if year_actions_complete():
		return
''',
'''func start_relationship_lifecycle_action(target_id: String, action_id: String) -> void:
	if not has_active_game():
		return
	var social_check := social_action_eligibility(target_id, action_id)
	if not bool(social_check.get("available", false)):
		state["recent_updates"]=[str(social_check.get("reason","That social action is not available."))]
		state_changed.emit()
		return
''',1)
text=text.replace(
'state["pending_turn"]={"activity":"socialize","kind":"relationship_lifecycle","target_id":target_id,"lifecycle_action":action_id,"status":"selected"}',
'state["pending_turn"]={"activity":"socialize","kind":"relationship_lifecycle","target_id":target_id,"lifecycle_action":action_id,"social_action_slot":true,"status":"selected"}',1)
text=text.replace(
'''func start_rivalry_action(target_id: String, action_id: String) -> void:
	if not has_active_game() or year_actions_complete() or not state.get("active_event", {}).is_empty() or not state.get("pending_turn", {}).is_empty():
		return
''',
'''func start_rivalry_action(target_id: String, action_id: String) -> void:
	if not has_active_game():
		return
	var social_check := social_action_eligibility(target_id, action_id)
	if not bool(social_check.get("available", false)):
		state["recent_updates"]=[str(social_check.get("reason","That social action is not available."))]
		state_changed.emit()
		return
''',1)
text=text.replace(
'state["pending_turn"]={"activity":"socialize","kind":"rivalry_lifecycle","target_id":target_id,"rivalry_action":action_id,"status":"selected"}',
'state["pending_turn"]={"activity":"socialize","kind":"rivalry_lifecycle","target_id":target_id,"rivalry_action":action_id,"social_action_slot":true,"status":"selected"}',1)

# Add child play result and a plain childhood Year Action.
text=text.replace(
'''\t\tmatch social_action:
\t\t\t"spend_time": result = RomanceSystemClass.spend_time(state, target_id)
\t\t\t"talk", "support": result = LifeDepthSystemClass.relationship_action(state, target_id, social_action)
''',
'''\t\tmatch social_action:
\t\t\t"play": result = _p89_play_together(target_id)
\t\t\t"spend_time": result = RomanceSystemClass.spend_time(state, target_id)
\t\t\t"talk", "support": result = LifeDepthSystemClass.relationship_action(state, target_id, social_action)
''',1)
text=text.replace(
'''\tmatch activity:
\t\t"study":
''',
'''\tmatch activity:
\t\t"play":
\t\t\tp["health"] = clampi(int(p.get("health", 100)) + 1, 0, 100)
\t\t\tif typeof(p.get("personality", null)) == TYPE_DICTIONARY:
\t\t\t\tp["personality"]["empathy"] = clampi(int(p["personality"].get("empathy", 50)) + 1, 0, 100)
\t\t\t_append_recent_updates(["You spend part of the year playing, exploring safely, and being a child."])
\t\t"study":
''',1)

# Helpers for family/friend play without abusing RomanceSystem.
anchor='func _p87_talent_value(character: Dictionary, key: String) -> int:\n'
helper='''func _p89_relationship_to(target_id: String) -> Dictionary:
	var player_id := str(state.get("player_id", ""))
	for rel_variant in state.get("relationships", {}).values():
		if typeof(rel_variant) != TYPE_DICTIONARY:
			continue
		var rel: Dictionary = rel_variant
		var a := str(rel.get("character_a", ""))
		var b := str(rel.get("character_b", ""))
		if (a == player_id and b == target_id) or (b == player_id and a == target_id):
			return rel
	return {}

func _p89_play_together(target_id: String) -> Dictionary:
	var target: Dictionary = state.get("characters", {}).get(target_id, {})
	if target.is_empty() or not bool(target.get("alive", true)):
		return {"ok":false,"message":"There is nobody here to play with."}
	var rel := _p89_relationship_to(target_id)
	if rel.is_empty():
		return {"ok":false,"message":"You do not know them well enough to play together yet."}
	rel["familiarity"] = clampi(int(rel.get("familiarity",0)) + 5, -100, 100)
	rel["comfort"] = clampi(int(rel.get("comfort",0)) + 5, -100, 100)
	rel["affection"] = clampi(int(rel.get("affection",0)) + 3, -100, 100)
	rel["trust"] = clampi(int(rel.get("trust",0)) + 1, -100, 100)
	return {"ok":true,"message":"You play with %s and spend easy time together." % str(target.get("first_name","them"))}

'''
if helper.strip() not in text:
    if anchor not in text: raise SystemExit("P89 helper anchor missing")
    text=text.replace(anchor,helper+anchor,1)

# Refresh Social Actions each year.
text=text.replace(
'state["calendar"]["turn_in_year"] = 0\n\tstate["calendar"]["year"] = int(state["calendar"].get("year", 312)) + 1',
'state["calendar"]["turn_in_year"] = 0\n\tstate["calendar"]["social_actions_used"] = 0\n\tstate["calendar"]["year"] = int(state["calendar"].get("year", 312)) + 1',1)
game.write_text(text,encoding="utf-8")

# ---------------------------------------------------------------------------
# UI: creator two-column layout, dedicated Friends and Inventory & Crafting,
# and explicit Year Action vs Social Action presentation.
# ---------------------------------------------------------------------------
ui=ROOT/"ui/main.gd"
text=ui.read_text(encoding="utf-8")

# Screen routing.
text=text.replace('\t\t"people": _show_people()\n', '\t\t"people": _show_people()\n\t\t"friends": _show_friends()\n',1)
text=text.replace('\t\t"character": _show_character()\n', '\t\t"character": _show_character()\n\t\t"inventory": _show_inventory_crafting()\n',1)

# Creator helper that can render into a column instead of always into root VBox.
if "func _creator_named_option_in(" not in text:
    s=text.find("func _creator_named_option(")
    if s<0: raise SystemExit("P89 creator helper missing")
    insert='''func _creator_named_option_in(parent: Container, label_text: String) -> OptionButton:
	var field := VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 18)
	field.add_child(label)
	var option := OptionButton.new()
	option.custom_minimum_size.y = 50
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_child(option)
	parent.add_child(field)
	return option

'''
    text=text[:s]+insert+text[s:]

creator='''func _show_new_life(slot: int) -> void:
	current_screen = "new_life"
	_clear_content()
	status_label.text = "Create your character"

	var identity_grid := GridContainer.new()
	identity_grid.columns = 2
	identity_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_grid.add_theme_constant_override("h_separation", 12)
	identity_grid.add_theme_constant_override("v_separation", 10)
	content.add_child(identity_grid)

	var name_box := VBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "Name"
	name_box.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Random if left blank"
	name_edit.custom_minimum_size.y = 52
	name_box.add_child(name_edit)
	identity_grid.add_child(name_box)

	var identity_box := VBoxContainer.new()
	var gender_label := Label.new()
	gender_label.text = "Identity"
	identity_box.add_child(gender_label)
	var gender := OptionButton.new()
	gender.add_item("Woman")
	gender.add_item("Man")
	gender.custom_minimum_size.y = 52
	identity_box.add_child(gender)
	identity_grid.add_child(identity_box)

	var columns := GridContainer.new()
	columns.name = "CreatorTwoColumnGrid"
	columns.columns = 2
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("h_separation", 14)
	columns.add_theme_constant_override("v_separation", 10)
	content.add_child(columns)

	var appearance_col := VBoxContainer.new()
	appearance_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(appearance_col)
	var appearance_title := Label.new()
	appearance_title.text = "Appearance"
	appearance_title.add_theme_font_size_override("font_size", 22)
	appearance_col.add_child(appearance_title)
	var appearance_grid := GridContainer.new()
	appearance_grid.columns = 2
	appearance_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	appearance_grid.add_theme_constant_override("h_separation", 8)
	appearance_grid.add_theme_constant_override("v_separation", 8)
	appearance_col.add_child(appearance_grid)
	var skin := _creator_named_option_in(appearance_grid, "Skin")
	var eyes := _creator_named_option_in(appearance_grid, "Eyes")
	var brows := _creator_named_option_in(appearance_grid, "Brows")
	var mouth := _creator_named_option_in(appearance_grid, "Mouth")
	var hairstyle := _creator_named_option_in(appearance_grid, "Hair")
	var outfit := _creator_named_option_in(appearance_grid, "Outfit")
	var randomize := Button.new()
	randomize.text = "RANDOMIZE LOOK"
	randomize.custom_minimum_size.y = 54
	appearance_col.add_child(randomize)
	var hair_note := Label.new()
	hair_note.text = "Hair is one complete matched style."
	hair_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	appearance_col.add_child(hair_note)

	var preview_col := VBoxContainer.new()
	preview_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(preview_col)
	var preview_title := Label.new()
	preview_title.text = "Preview"
	preview_title.add_theme_font_size_override("font_size", 22)
	preview_col.add_child(preview_title)
	var preview_holder := CenterContainer.new()
	preview_holder.custom_minimum_size = Vector2(180, 245)
	preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_col.add_child(preview_holder)
	var preview = PortraitWidgetClass.new()
	preview.custom_minimum_size = Vector2(180, 220)
	preview_holder.add_child(preview)

	var bloodline_rng := RandomNumberGenerator.new()
	bloodline_rng.randomize()
	var lineage_state := {"selected": LineageSystemClass.roll(bloodline_rng), "rerolls_left": 3}
	var bloodline_title := Label.new()
	bloodline_title.text = "Bloodline"
	bloodline_title.add_theme_font_size_override("font_size", 21)
	preview_col.add_child(bloodline_title)
	var bloodline_label := Label.new()
	bloodline_label.name = "BloodlinePreview"
	bloodline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bloodline_label.add_theme_font_size_override("font_size", 17)
	preview_col.add_child(bloodline_label)
	var bloodline_button := Button.new()
	bloodline_button.name = "BloodlineRerollButton"
	bloodline_button.custom_minimum_size.y = 50
	preview_col.add_child(bloodline_button)

	var repopulate := func():
		var identity := PortraitCatalogSystemClass.identity_for_gender(gender.get_item_text(gender.selected))
		skin.clear()
		for tone in PortraitCatalogSystemClass.SKIN_TONES:
			skin.add_item(str(tone).capitalize())
			skin.set_item_metadata(skin.item_count - 1, tone)
		for pair in [[eyes, "eyes"], [brows, "brows"], [mouth, "mouth"], [outfit, "outfit"]]:
			var control: OptionButton = pair[0]
			control.clear()
			for asset in PortraitCatalogSystemClass.standard_assets(identity, str(pair[1])):
				control.add_item(str(asset.get("label_en", str(asset.get("id", "Option")).replace("_", " ").capitalize())))
				control.set_item_metadata(control.item_count - 1, str(asset.get("id", "")))
		hairstyle.clear()
		for style in PortraitCatalogSystemClass.standard_hairstyles(identity):
			hairstyle.add_item(str(style.get("label_en", str(style.get("id", "Hair")).replace("_", " ").capitalize())))
			hairstyle.set_item_metadata(hairstyle.item_count - 1, str(style.get("id", "")))

	var build_preview_data := func() -> Dictionary:
		var identity := PortraitCatalogSystemClass.identity_for_gender(gender.get_item_text(gender.selected))
		var state := {
			"identity": identity,
			"skin_tone": str(skin.get_item_metadata(skin.selected)),
			"hairstyle_id": str(hairstyle.get_item_metadata(hairstyle.selected)),
			"eyes_id": str(eyes.get_item_metadata(eyes.selected)),
			"brows_id": str(brows.get_item_metadata(brows.selected)),
			"mouth_id": str(mouth.get_item_metadata(mouth.selected)),
			"outfit_id": str(outfit.get_item_metadata(outfit.selected))
		}
		return {"age":18,"gender":gender.get_item_text(gender.selected),"appearance":PortraitCatalogSystemClass.normalize_standard(state, identity)}

	var refresh_preview := func(_index = 0):
		preview.set_character(build_preview_data.call())

	var refresh_bloodline := func():
		var selected: Dictionary = lineage_state["selected"]
		var rerolls_left := int(lineage_state["rerolls_left"])
		bloodline_label.text = "%s • %s\\n%s" % [
			str(selected.get("name","Unknown")),
			str(selected.get("tier","Common")),
			LineageSystemClass.benefit_text(selected)
		]
		bloodline_button.text = "REROLL (%d LEFT)" % rerolls_left
		bloodline_button.disabled = rerolls_left <= 0

	repopulate.call()
	refresh_preview.call()
	refresh_bloodline.call()
	for option in [skin,eyes,brows,mouth,hairstyle,outfit]:
		option.item_selected.connect(refresh_preview)
	gender.item_selected.connect(func(_index):
		repopulate.call()
		refresh_preview.call()
	)
	randomize.pressed.connect(func():
		for option in [skin,eyes,brows,mouth,hairstyle,outfit]:
			if option.item_count > 0:
				option.select(randi_range(0, option.item_count - 1))
		refresh_preview.call()
	)
	bloodline_button.pressed.connect(func():
		if int(lineage_state["rerolls_left"]) <= 0:
			return
		lineage_state["selected"] = LineageSystemClass.roll(bloodline_rng)
		lineage_state["rerolls_left"] = int(lineage_state["rerolls_left"]) - 1
		refresh_bloodline.call()
	)

	var footer := GridContainer.new()
	footer.columns = 2
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("h_separation", 10)
	content.add_child(footer)
	var begin := Button.new()
	begin.text = "BEGIN LIFE"
	begin.custom_minimum_size.y = 64
	begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	begin.pressed.connect(func():
		var p: Dictionary = build_preview_data.call()
		Game.new_life(slot, name_edit.text, str(p["gender"]), p["appearance"], lineage_state["selected"])
	)
	footer.add_child(begin)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size.y = 64
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_show_main_menu)
	footer.add_child(back)
	_style_all_buttons()
'''
s,e,_=function_block(text,"_show_new_life")
if s<0: raise SystemExit("P89 creator function missing")
text=text[:s]+creator+"\n\n"+text[e+1:]

# Life screen: Year Actions only; Social Actions explicitly separate.
text=text.replace(
'\tif age <= 5:\n\t\t_add_text("Infancy still shows future activities below. Locked buttons explain exactly when they become available.")\n',
'\tif age <= 5:\n\t\t_add_text("Childhood is playable now: Play, Family, Rest, and separate Social Actions stay available. Older activities remain visible with their unlock age.")\n',1)
text=text.replace('_add_section_title("Activities")','_add_section_title("Year Actions")',1)
text=text.replace(
'for activity in ["study", "train", "work", "family", "socialize", "rest"]:',
'for activity in ["play", "study", "train", "work", "family", "rest"]:',1)
text=text.replace(
'''\t\tvar eligibility: Dictionary = Game.activity_eligibility(activity)
\t\tvar available := bool(eligibility.get("available", false))
''',
'''\t\tif activity == "play" and age > 12:
\t\t\tcontinue
\t\tvar eligibility: Dictionary = Game.activity_eligibility(activity)
\t\tvar available := bool(eligibility.get("available", false))
''',1)
insert_after='''\tif not activity_lock_notes.is_empty():
\t\t_add_text("Locked actions:\\n• %s" % "\\n• ".join(activity_lock_notes))
'''
if insert_after not in text: raise SystemExit("P89 life lock note anchor missing")
text=text.replace(insert_after,insert_after+'''\t_add_text("Social Actions are separate from Year Actions: %d/%d remaining. Use Friends, Family, or People." % [Game.social_actions_remaining(), Game.social_actions_per_year()])
''',1)

# Remove Crafting from Career; it gets a dedicated screen.
s,e,career=function_block(text,"_show_career")
cs=career.find('\t_add_section_title("Crafting & materials")')
ce=career.find('\t_add_section_title("Mentorship & apprenticeship")')
if cs>=0 and ce>cs:
    career=career[:cs]+career[ce:]
text=text[:s]+career+text[e:]

# Remove possession/shop block from Character.
s,e,char=function_block(text,"_show_character")
cs=char.find('\t_add_section_title("Possessions & equipment")')
ce=char.find('\t_add_section_title("Household economy")')
if cs>=0 and ce>cs:
    char=char[:cs]+char[ce:]
# Household economy still shows practical-item count after the inventory block
# moved out, so declare the summary locally instead of relying on the removed block.
char=char.replace(
    '\t_add_section_title("Household economy")\n',
    '\tvar possession_summary: Dictionary = Game.possession_summary()\n\t_add_section_title("Household economy")\n',
    1
)
text=text[:s]+char+text[e:]

friends_func='''func _show_friends() -> void:
	current_screen = "friends"
	_clear_content()
	status_label.text = "Friends"
	_add_section_title("Friends")
	_add_text("Social Actions are separate from Year Actions. You have %d/%d Social Actions left this year." % [Game.social_actions_remaining(), Game.social_actions_per_year()])
	var player_id := str(Game.state.get("player_id", ""))
	var rows: Array = []
	for rel_variant in Game.state.get("relationships", {}).values():
		if typeof(rel_variant) != TYPE_DICTIONARY:
			continue
		var rel: Dictionary = rel_variant
		var a := str(rel.get("character_a", ""))
		var b := str(rel.get("character_b", ""))
		if player_id not in [a,b]:
			continue
		var roles: Array = rel.get("roles", [])
		if "friend" not in roles and "childhood_friend" not in roles:
			continue
		var other_id := b if a == player_id else a
		var person: Dictionary = Game.state.get("characters", {}).get(other_id, {})
		if person.is_empty() or not bool(person.get("alive", true)):
			continue
		rows.append({"char":person,"rel":rel})
	rows.sort_custom(func(x,y): return int(x["rel"].get("familiarity",0)) > int(y["rel"].get("familiarity",0)))
	if rows.is_empty():
		_add_text("No close friends yet. Talk, play, and spend time with people to let friendships grow naturally.")
	else:
		for row in rows:
			_add_person_card_with_actions(row["char"], "Friend", row["rel"])
	_add_navigation()
'''
# Insert before career
idx=text.find("func _show_career()")
if idx<0: raise SystemExit("P89 career insert anchor missing")
text=text[:idx]+friends_func+"\n\n"+text[idx:]

inventory_func='''func _show_inventory_crafting() -> void:
	current_screen = "inventory"
	_clear_content()
	status_label.text = "Inventory & Crafting"
	var p := Game.player()

	var summary: Dictionary = Game.possession_summary()
	var bonuses: Dictionary = summary.get("bonuses", {})
	_add_section_title("Equipped")
	_add_text("Items %d • Inventory value %d gold\\nCombat +%d • Guard +%d • Travel +%d • Work +%d • Mana +%d" % [
		int(summary.get("owned_count",0)), int(summary.get("inventory_value",0)),
		int(bonuses.get("combat_power",0)), int(bonuses.get("combat_guard",0)),
		int(bonuses.get("travel_safety",0)), int(bonuses.get("work_quality",0)),
		int(bonuses.get("mana_focus",0))
	])
	var equipped_rows: Dictionary = summary.get("equipment", {})
	var equip_grid := GridContainer.new()
	equip_grid.columns = 2
	equip_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(equip_grid)
	for slot in ["weapon","tool","travel","charm"]:
		var equipped: Dictionary = equipped_rows.get(slot,{})
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := Label.new()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s\\n%s" % [slot.capitalize(), "Empty" if equipped.is_empty() else str(equipped.get("label","Item"))]
		card.add_child(label)
		if not equipped.is_empty():
			var b := Button.new()
			b.text = "Unequip"
			b.pressed.connect(Game.unequip_possession.bind(slot))
			card.add_child(b)
		equip_grid.add_child(card)

	_add_section_title("Inventory")
	var owned: Array = Game.owned_possessions()
	if owned.is_empty():
		_add_text("No practical items owned yet.")
	else:
		var inv_grid := GridContainer.new()
		inv_grid.columns = 2
		inv_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		inv_grid.add_theme_constant_override("h_separation",8)
		inv_grid.add_theme_constant_override("v_separation",8)
		content.add_child(inv_grid)
		for item in owned:
			var card := VBoxContainer.new()
			card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var label := Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.text = "%s\\n%s%s" % [str(item.get("label","Item")),str(item.get("slot","gear")).capitalize()," • Equipped" if bool(item.get("equipped",false)) else ""]
			card.add_child(label)
			if not bool(item.get("equipped",false)):
				var equip := Button.new()
				equip.text = "Equip"
				equip.pressed.connect(Game.equip_possession.bind(str(item.get("instance_id",""))))
				card.add_child(equip)
			inv_grid.add_child(card)

	_add_section_title("Crafting")
	var crafting_access: Dictionary = Game.feature_eligibility("crafting")
	var crafting: Dictionary = Game.crafting_summary()
	_add_text("Skill %d • Gathered %d • Crafted %d • Materials worth %d gold" % [int(crafting.get("crafting_skill",0)),int(crafting.get("gathers",0)),int(crafting.get("crafts",0)),int(crafting.get("material_value",0))])
	var material_bits:=PackedStringArray()
	for material in crafting.get("materials",[]):
		if int(material.get("amount",0))>0:
			material_bits.append("%s x%d" % [str(material.get("label","Material")),int(material.get("amount",0))])
	_add_text("Materials: %s" % (", ".join(material_bits) if not material_bits.is_empty() else "None"))
	if not bool(crafting_access.get("available",false)):
		_add_text("Unlock: %s" % str(crafting_access.get("reason","Crafting is unavailable.")))
	else:
		var craft_grid := GridContainer.new()
		craft_grid.columns = 2
		craft_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content.add_child(craft_grid)
		for option in Game.crafting_gather_options():
			if not bool(option.get("available",false)):
				continue
			var gather := Button.new()
			gather.text = "Gather • %s" % str(option.get("label","Materials"))
			gather.disabled = Game.year_actions_complete()
			gather.pressed.connect(Game.gather_crafting_materials.bind(str(option.get("id",""))))
			craft_grid.add_child(gather)
		for recipe in Game.crafting_recipe_options():
			var recipe_button := Button.new()
			recipe_button.text = "%s%s" % ["🔒 " if not bool(recipe.get("available",false)) else "",str(recipe.get("label","Recipe"))]
			recipe_button.disabled = Game.year_actions_complete() or not bool(recipe.get("available",false))
			recipe_button.tooltip_text = str(recipe.get("reason",""))
			recipe_button.pressed.connect(Game.craft_recipe.bind(str(recipe.get("id",""))))
			craft_grid.add_child(recipe_button)

	_add_section_title("Material Market")
	var market_grid := GridContainer.new()
	market_grid.columns = 2
	market_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(market_grid)
	for market_row in Game.crafting_market():
		var b := Button.new()
		b.text = "%s%s • %d gold" % ["🔒 " if not bool(market_row.get("available",false)) else "",str(market_row.get("label","Material")),int(market_row.get("price",0))]
		b.disabled = not bool(market_row.get("available",false))
		b.tooltip_text = str(market_row.get("reason",""))
		b.pressed.connect(Game.buy_crafting_material.bind(str(market_row.get("id",""))))
		market_grid.add_child(b)

	_add_section_title("Equipment Shop")
	_add_text("Shop purchases do not use a Year Action. Locked items show their real requirement.")
	var shop_grid := GridContainer.new()
	shop_grid.columns = 2
	shop_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(shop_grid)
	for item in Game.possession_catalog():
		var available := bool(item.get("available",false))
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var buy := Button.new()
		buy.text = "%s%s • %d gold" % ["🔒 " if not available else "",str(item.get("label","Item")),int(item.get("price",0))]
		buy.disabled = not available
		buy.pressed.connect(Game.buy_possession.bind(str(item.get("id",""))))
		card.add_child(buy)
		var note := Label.new()
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.text = str(item.get("description","")) + ("" if available else "\\nUnlock: " + str(item.get("reason","Unavailable.")))
		card.add_child(note)
		shop_grid.add_child(card)
	_add_navigation()
'''
idx=text.find("func _show_world()")
if idx<0: raise SystemExit("P89 world insert anchor missing")
text=text[:idx]+inventory_func+"\n\n"+text[idx:]

# Replace person action card with explicit Social Actions and child play.
s,e,block=function_block(text,"_add_person_card_with_actions")
if s<0: raise SystemExit("P89 person actions missing")
# minimally transform existing block rather than recreate the deep relationship controls.
block=block.replace('\tif player_age < 6:\n\t\treturn\n','')
block=block.replace(
'''\tvar action_grid := GridContainer.new()
''',
'''\t_add_text("Social Actions • %d/%d remaining" % [Game.social_actions_remaining(), Game.social_actions_per_year()])
\tvar action_grid := GridContainer.new()
''',1)
block=block.replace('talk.disabled = Game.year_actions_complete()','talk.disabled = not bool(Game.social_action_eligibility(target_id, "talk").get("available", false))')
block=block.replace('spend.disabled = Game.year_actions_complete()','spend.disabled = not bool(Game.social_action_eligibility(target_id, "spend_time").get("available", false))')
block=block.replace('support.disabled = Game.year_actions_complete()','support.disabled = not bool(Game.social_action_eligibility(target_id, "support").get("available", false))')
block=block.replace('mentor_button.disabled = Game.year_actions_complete() or not bool(mentorship.get("available", false))','mentor_button.disabled = not bool(mentorship.get("available", false))')
block=block.replace('rivalry_button.disabled=Game.year_actions_complete()','rivalry_button.disabled=not bool(Game.social_action_eligibility(target_id,rivalry_action).get("available",false))')
block=block.replace('repair_button.disabled=Game.year_actions_complete() or not bool(repair_check.get("available",false))','repair_button.disabled=not bool(Game.social_action_eligibility(target_id,"repair").get("available",false)) or not bool(repair_check.get("available",false))')
block=block.replace('end_button.disabled=Game.year_actions_complete()','end_button.disabled=not bool(Game.social_action_eligibility(target_id,"end").get("available",false))')
block=block.replace('reconcile_button.disabled=Game.year_actions_complete() or not bool(reconcile_check.get("available",false))','reconcile_button.disabled=not bool(Game.social_action_eligibility(target_id,"reconcile").get("available",false)) or not bool(reconcile_check.get("available",false))')
block=block.replace('confess.disabled = Game.year_actions_complete()','confess.disabled = not bool(Game.social_action_eligibility(target_id, "confess").get("available", false))')
block=block.replace('propose.disabled = Game.year_actions_complete()','propose.disabled = not bool(Game.social_action_eligibility(target_id, "propose").get("available", false))')
# Child play button before Talk.
anchor='\tvar talk := Button.new()\n'
play='''\tif player_age <= 12:
\t\tvar play_button := Button.new()
\t\tplay_button.text = "Play together"
\t\tplay_button.custom_minimum_size.y = 48
\t\tplay_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
\t\tplay_button.disabled = not bool(Game.social_action_eligibility(target_id, "play").get("available", false))
\t\tplay_button.pressed.connect(Game.start_relationship_action.bind(target_id, "play"))
\t\taction_grid.add_child(play_button)
'''
if anchor not in block: raise SystemExit("P89 person talk anchor missing")
block=block.replace(anchor,play+anchor,1)
# Very young children can play and be with people; conventional talk starts at 4.
block=block.replace(
'\tvar talk := Button.new()\n\ttalk.text = "Talk"\n',
'\tvar talk := Button.new()\n\ttalk.text = "Talk"\n\ttalk.visible = player_age >= 4\n',1)
text=text[:s]+block+text[e:]

# Navigation categories.
text=text.replace(
'var labels := [["Life", "life"], ["Career", "career"], ["Adventure", "adventure"], ["Character", "character"], ["Family", "family"], ["People", "people"], ["World", "world"], ["Chronicle", "chronicle"], ["Audio", "settings"]]',
'var labels := [["Life","life"],["Career","career"],["Adventure","adventure"],["Character","character"],["Family","family"],["Friends","friends"],["People","people"],["Inventory & Crafting","inventory"],["World","world"],["Chronicle","chronicle"],["Audio","settings"]]',1)
text=text.replace(
'if current_screen in ["life", "turn_result", "career", "adventure", "family", "people", "character", "world", "chronicle"]:',
'if current_screen in ["life","turn_result","career","adventure","family","friends","people","inventory","character","world","chronicle"]:',1)

ui.write_text(text,encoding="utf-8")

# ---------------------------------------------------------------------------
# Inherited smoke: update old "all infant actions locked" wording/assumptions.
# ---------------------------------------------------------------------------
smoke=ROOT/"tests/runtime_smoke.gd"
st=smoke.read_text(encoding="utf-8")
st=st.replace(
'''• Study — Unlocks at age 6.
• Train — Unlocks at age 6.
• Work — Unlocks at age 6.
• Family — Unlocks at age 6.
• Socialize — Unlocks at age 6.
• Rest — Unlocks at age 6.''',
'''• Study — Study unlocks at age 6.
• Train — Structured training unlocks at age 10.
• Work — Work unlocks at age 14. Younger children can Play, spend Family time, or Rest.''')
st=st.replace(
'for locked_action in ["study","train","work","family","socialize","adventure","travel","career"]:',
'for locked_action in ["study","train","work","adventure","travel","career"]:',1)
st=st.replace(
'for required in ["Skin tone", "Eyes", "Brows", "Mouth", "Hairstyle", "Outfit", "Bloodline"]:',
'for required in ["Skin", "Eyes", "Brows", "Mouth", "Hair", "Outfit", "Bloodline"]:',1)
# P50 originally verified the equipment shop on Character. P89 intentionally
# moves that ownership to Inventory & Crafting; keep the lock/reason regression,
# but assert it on the new screen rather than restoring obsolete UI.
st=st.replace(
'main.call("_show_screen", "character")\n\tawait process_frame\n\t_check(_has_text(main, "Possessions & equipment"), "P50 Character screen missing possession section")\n\tvar locked_practice = _find_button(main, "🔒 Wooden Practice Sword • 6 gold")\n\t_check(locked_practice != null and bool(locked_practice.disabled), "P50 Character screen hides or enables age-locked practice sword")\n\t_check(_has_text(main, "Weapon • A balanced wooden sword for controlled practice rather than real fighting.\\nUnlock: Requires age 10."), "P50 locked item does not show exact unlock reason")',
'main.call("_show_screen", "inventory")\n\tawait process_frame\n\t_check(_has_text(main, "Inventory & Crafting") and _has_text(main, "Equipment Shop"), "P89 Inventory screen missing equipment shop")\n\tvar locked_practice = _find_button(main, "🔒 Wooden Practice Sword • 6 gold")\n\t_check(locked_practice != null and bool(locked_practice.disabled), "P89 Inventory screen hides or enables age-locked practice sword")\n\t_check(_has_text(main, "A balanced wooden sword for controlled practice rather than real fighting.\\nUnlock: Requires age 10."), "P89 locked equipment does not show exact unlock reason")',
1)
# Move the exact inherited P50 possession UI assertions to P89's new owner.
p50_anchor='PossessionSystemClass.ensure_state(game.state)\n\tmain.call("_show_screen", "character")'
if p50_anchor in st:
    st=st.replace(p50_anchor,'PossessionSystemClass.ensure_state(game.state)\n\tmain.call("_show_screen", "inventory")',1)
st=st.replace(
    '_check(_has_text(main, "Possessions & equipment"), "P50 Character screen missing possession section")',
    '_check(_has_text(main, "Inventory & Crafting") and _has_text(main, "Equipment Shop"), "P89 Inventory screen missing equipment shop")',1)
st=st.replace(
    '"P50 Character screen hides or enables age-locked practice sword"',
    '"P89 Inventory screen hides or enables age-locked practice sword"',1)
st=st.replace(
    '"Weapon • A balanced wooden sword for controlled practice rather than real fighting.\\nUnlock: Requires age 10."',
    '"Requires age 10."',1)
st=st.replace(
    '"A balanced wooden sword for controlled practice rather than real fighting.\\nUnlock: Requires age 10."',
    '"Requires age 10."',1)
# The inherited P50 source contains a literal newline inside this GDScript
# string, so replace the stable prefix rather than trying to match escaped \n.
st=st.replace(
    '"Weapon • A balanced wooden sword for controlled practice rather than real fighting.',
    '"A balanced wooden sword for controlled practice rather than real fighting.',1)
st=st.replace(
    '"P50 locked item does not show exact unlock reason"',
    '"P89 locked equipment does not show exact unlock reason"',1)
# P14-era mobile smoke treated Socialize as a Year Action. P89 splits that
# budget deliberately, so preserve the two-column Year Action grid while
# removing Socialize from it and verifying the new navigation owners.
st=st.replace(
    'for activity_label in ["Study", "Train", "Work", "Family", "Socialize", "Rest"]:',
    'for activity_label in ["Study", "Train", "Work", "Family", "Rest"]:',1)
st=st.replace(
    'for nav_label in ["Life", "Career", "Adventure", "Character", "Family", "People", "World", "Chronicle"]:',
    'for nav_label in ["Life", "Career", "Adventure", "Character", "Family", "Friends", "People", "Inventory & Crafting", "World", "Chronicle"]:',1)
smoke.write_text(st,encoding="utf-8")

# Keep P87's QOL regression meaningful after the compact two-column creator.
# It must still prove English UI + a visible real portrait, but P89 intentionally
# shortens the Hair label and uses a narrower phone-friendly preview.
q87 = ROOT / "tests/qol_balance_test.gd"
q87_text = q87.read_text(encoding="utf-8")
q87_text = q87_text.replace(
    '_check(_has_text(main, "Hairstyle"), "English Hairstyle control is missing")',
    '_check(_has_text(main, "Hair"), "English Hair control is missing")',
    1
)
q87_text = q87_text.replace(
    'preview.custom_minimum_size.x >= 200.0 and preview.custom_minimum_size.y >= 240.0',
    'preview.custom_minimum_size.x >= 170.0 and preview.custom_minimum_size.y >= 210.0',
    1
)
q87.write_text(q87_text, encoding="utf-8")


# ---------------------------------------------------------------------------
# P89 mobile UX correction: vertical-only scrolling, responsive creator,
# exported-build-safe modular portrait loading, and inline action results.
# ---------------------------------------------------------------------------

# Exported Android builds package imported textures; load portrait layers as
# Texture2D resources instead of attempting to read source PNGs directly.
catalog = ROOT / "ui/widgets/portrait_catalog_system.gd"
new_load_asset = '''func load_asset_image(asset: Dictionary, important: bool = false) -> Image:
	var root := IMPORTANT_ROOT if important else STANDARD_ROOT
	var key := ("important:" if important else "standard:") + str(asset.get("id", ""))
	if _asset_cache.has(key):
		return _asset_cache[key]
	var path := root + str(asset.get("path", ""))

	# Source/test builds keep the raw PNG, while exported Android builds may
	# remap it to an imported Texture2D. Prefer the raw image when present so
	# headless source tests stay quiet, then fall back to ResourceLoader for APK.
	if FileAccess.file_exists(path):
		var raw := Image.new()
		if raw.load(path) == OK and raw.get_size() == Vector2i(160, 176):
			_asset_cache[key] = raw
			return raw

	var resource: Resource = ResourceLoader.load(path)
	if resource == null or not (resource is Texture2D):
		return null
	var image: Image = (resource as Texture2D).get_image()
	if image == null or image.get_size() != Vector2i(160, 176):
		return null
	_asset_cache[key] = image
	return image
'''
old_load_asset = '''func load_asset_image(asset: Dictionary, important: bool = false) -> Image:
	var root := IMPORTANT_ROOT if important else STANDARD_ROOT
	var key := ("important:" if important else "standard:") + str(asset.get("id", ""))
	if _asset_cache.has(key):
		return _asset_cache[key]
	var path := root + str(asset.get("path", ""))
	var image := Image.new()
	var err := image.load(path)
	if err != OK or image.get_size() != Vector2i(160, 176):
		return null
	_asset_cache[key] = image
	return image
'''
replace_once(catalog, old_load_asset, new_load_asset, "export-safe portrait asset loader")

# Respect caller-supplied portrait size and keep the TextureRect behind
# expression overlays. This prevents the preview from forcing horizontal width.
portrait = ROOT / "ui/widgets/portrait_widget.gd"
new_portrait_ready = '''func _ready() -> void:
	if custom_minimum_size.x <= 0.0 or custom_minimum_size.y <= 0.0:
		custom_minimum_size = Vector2(200, 220)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_display = TextureRect.new()
	_display.name = "PortraitTexture"
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Keep the texture behind this widget's expression overlay without sending
	# it behind the page/background on Android. Negative z-index made the
	# composed portrait invisible on real devices.
	_display.z_index = 0
	_display.show_behind_parent = true
	add_child(_display)
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	_refresh_texture()
'''
replace_function(portrait, "_ready", new_portrait_ready)

# Keep the app vertically scrollable only.
ui = ROOT / "ui/main.gd"
text = ui.read_text(encoding="utf-8")
text = text.replace(
	'''	scroll_view = ScrollContainer.new()
	scroll_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
''',
	'''	scroll_view = ScrollContainer.new()
	scroll_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_view.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_view.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
''',
	1
)

# Compact option controls must not widen the whole creator to their longest item.
s, e, helper_block = function_block(text, "_creator_named_option_in")
if s < 0:
	raise SystemExit("P89 creator option helper missing")
helper_block = helper_block.replace(
	'''	var option := OptionButton.new()
	option.custom_minimum_size.y = 50
''',
	'''	var option := OptionButton.new()
	option.fit_to_longest_item = false
	option.custom_minimum_size = Vector2(0, 50)
''',
	1
)
text = text[:s] + helper_block.rstrip() + "\n\n" + text[e+1:]

# Creator is a vertical stack. Only short fields use two columns; portrait,
# hair/outfit, bloodline copy and long information are full-width.
creator_vertical = '''func _show_new_life(slot: int) -> void:
	current_screen = "new_life"
	_clear_content()
	status_label.text = "Create your character"

	var identity_grid := GridContainer.new()
	identity_grid.name = "CreatorIdentityGrid"
	identity_grid.columns = 2
	identity_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_grid.add_theme_constant_override("h_separation", 10)
	identity_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(identity_grid)

	var name_box := VBoxContainer.new()
	name_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_label := Label.new()
	name_label.text = "Name"
	name_box.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.placeholder_text = "Random if blank"
	name_edit.custom_minimum_size = Vector2(0, 50)
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_box.add_child(name_edit)
	identity_grid.add_child(name_box)

	var identity_box := VBoxContainer.new()
	identity_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var gender_label := Label.new()
	gender_label.text = "Identity"
	identity_box.add_child(gender_label)
	var gender := OptionButton.new()
	gender.fit_to_longest_item = false
	gender.add_item("Woman")
	gender.add_item("Man")
	gender.custom_minimum_size = Vector2(0, 50)
	gender.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_box.add_child(gender)
	identity_grid.add_child(identity_box)

	_add_section_title("Appearance")
	var short_grid := GridContainer.new()
	short_grid.name = "CreatorAppearanceTwoColumnGrid"
	short_grid.columns = 2
	short_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	short_grid.add_theme_constant_override("h_separation", 8)
	short_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(short_grid)
	var skin := _creator_named_option_in(short_grid, "Skin")
	var eyes := _creator_named_option_in(short_grid, "Eyes")
	var brows := _creator_named_option_in(short_grid, "Brows")
	var mouth := _creator_named_option_in(short_grid, "Mouth")

	var long_fields := VBoxContainer.new()
	long_fields.name = "CreatorLongFields"
	long_fields.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	long_fields.add_theme_constant_override("separation", 8)
	content.add_child(long_fields)
	var hairstyle := _creator_named_option_in(long_fields, "Hair")
	var outfit := _creator_named_option_in(long_fields, "Outfit")

	var randomize := Button.new()
	randomize.text = "RANDOMIZE LOOK"
	randomize.custom_minimum_size.y = 54
	randomize.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(randomize)
	var hair_note := Label.new()
	hair_note.text = "Hair is one complete matched style."
	hair_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hair_note)

	_add_section_title("Preview")
	var preview_holder := CenterContainer.new()
	preview_holder.name = "CreatorPreviewHolder"
	preview_holder.custom_minimum_size = Vector2(0, 238)
	preview_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(preview_holder)
	var preview = PortraitWidgetClass.new()
	preview.custom_minimum_size = Vector2(190, 210)
	preview_holder.add_child(preview)

	var bloodline_rng := RandomNumberGenerator.new()
	bloodline_rng.randomize()
	var lineage_state := {"selected": LineageSystemClass.roll(bloodline_rng), "rerolls_left": 3}
	_add_section_title("Bloodline")
	var bloodline_label := Label.new()
	bloodline_label.name = "BloodlinePreview"
	bloodline_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bloodline_label.add_theme_font_size_override("font_size", 17)
	bloodline_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(bloodline_label)
	var bloodline_button := Button.new()
	bloodline_button.name = "BloodlineRerollButton"
	bloodline_button.custom_minimum_size.y = 50
	bloodline_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(bloodline_button)

	var repopulate := func():
		var identity := PortraitCatalogSystemClass.identity_for_gender(gender.get_item_text(gender.selected))
		skin.clear()
		for tone in PortraitCatalogSystemClass.SKIN_TONES:
			skin.add_item(str(tone).capitalize())
			skin.set_item_metadata(skin.item_count - 1, tone)
		for pair in [[eyes, "eyes"], [brows, "brows"], [mouth, "mouth"], [outfit, "outfit"]]:
			var control: OptionButton = pair[0]
			control.clear()
			control.fit_to_longest_item = false
			for asset in PortraitCatalogSystemClass.standard_assets(identity, str(pair[1])):
				control.add_item(str(asset.get("label_en", str(asset.get("id", "Option")).replace("_", " ").capitalize())))
				control.set_item_metadata(control.item_count - 1, str(asset.get("id", "")))
		hairstyle.clear()
		hairstyle.fit_to_longest_item = false
		for style in PortraitCatalogSystemClass.standard_hairstyles(identity):
			hairstyle.add_item(str(style.get("label_en", str(style.get("id", "Hair")).replace("_", " ").capitalize())))
			hairstyle.set_item_metadata(hairstyle.item_count - 1, str(style.get("id", "")))

	var build_preview_data := func() -> Dictionary:
		var identity := PortraitCatalogSystemClass.identity_for_gender(gender.get_item_text(gender.selected))
		var appearance := {
			"identity": identity,
			"skin_tone": str(skin.get_item_metadata(skin.selected)),
			"hairstyle_id": str(hairstyle.get_item_metadata(hairstyle.selected)),
			"eyes_id": str(eyes.get_item_metadata(eyes.selected)),
			"brows_id": str(brows.get_item_metadata(brows.selected)),
			"mouth_id": str(mouth.get_item_metadata(mouth.selected)),
			"outfit_id": str(outfit.get_item_metadata(outfit.selected))
		}
		return {
			"age":18,
			"gender":gender.get_item_text(gender.selected),
			"appearance":PortraitCatalogSystemClass.normalize_standard(appearance, identity)
		}

	var refresh_preview := func(_index = 0):
		preview.set_character(build_preview_data.call())

	var refresh_bloodline := func():
		var selected: Dictionary = lineage_state["selected"]
		var rerolls_left := int(lineage_state["rerolls_left"])
		bloodline_label.text = "%s • %s\\n%s" % [
			str(selected.get("name","Unknown")),
			str(selected.get("tier","Common")),
			LineageSystemClass.benefit_text(selected)
		]
		bloodline_button.text = "REROLL (%d LEFT)" % rerolls_left
		bloodline_button.disabled = rerolls_left <= 0

	repopulate.call()
	refresh_preview.call()
	refresh_bloodline.call()
	for option in [skin,eyes,brows,mouth,hairstyle,outfit]:
		option.item_selected.connect(refresh_preview)
	gender.item_selected.connect(func(_index):
		repopulate.call()
		refresh_preview.call()
	)
	randomize.pressed.connect(func():
		for option in [skin,eyes,brows,mouth,hairstyle,outfit]:
			if option.item_count > 0:
				option.select(randi_range(0, option.item_count - 1))
		refresh_preview.call()
	)
	bloodline_button.pressed.connect(func():
		if int(lineage_state["rerolls_left"]) <= 0:
			return
		lineage_state["selected"] = LineageSystemClass.roll(bloodline_rng)
		lineage_state["rerolls_left"] = int(lineage_state["rerolls_left"]) - 1
		refresh_bloodline.call()
	)

	var footer := GridContainer.new()
	footer.name = "CreatorFooterGrid"
	footer.columns = 2
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_theme_constant_override("h_separation", 8)
	content.add_child(footer)
	var begin := Button.new()
	begin.text = "BEGIN LIFE"
	begin.custom_minimum_size.y = 62
	begin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	begin.pressed.connect(func():
		var p: Dictionary = build_preview_data.call()
		Game.new_life(slot, name_edit.text, str(p["gender"]), p["appearance"], lineage_state["selected"])
	)
	footer.add_child(begin)
	var back := Button.new()
	back.text = "Back"
	back.custom_minimum_size.y = 62
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back.pressed.connect(_show_main_menu)
	footer.add_child(back)
	_style_all_buttons()
'''
# Replace the P89 creator already generated earlier in this script.
ui.write_text(text, encoding="utf-8")
replace_function(ui, "_show_new_life", creator_vertical)

# Inline screen routing: ordinary actions refresh the current page; only events
# that require a choice temporarily open the event view, then return to origin.
text = ui.read_text(encoding="utf-8")
text = text.replace(
	'Game.screen_requested.connect(_show_screen)',
	'Game.screen_requested.connect(_handle_screen_request)',
	1
)
text = text.replace(
	'var current_screen := "menu"\\n',
	'var current_screen := "menu"\\nvar _event_return_screen := "life"\\nvar _event_return_scroll := 0\\n',
	1
)

handle = '''func _handle_screen_request(screen_name: String) -> void:
	if screen_name == "event":
		if current_screen != "event":
			_event_return_screen = current_screen if current_screen not in ["menu","new_life","birth_reveal"] else "life"
			_event_return_scroll = scroll_view.scroll_vertical if scroll_view != null else 0
		_show_screen("event")
		return
	if screen_name in ["turn_result", "return_from_event"]:
		var target := _event_return_screen if current_screen == "event" else current_screen
		if target in ["event","turn_result","menu","new_life"]:
			target = "life"
		_show_screen(target)
		call_deferred("_restore_scroll", _event_return_scroll if screen_name == "return_from_event" else (scroll_view.scroll_vertical if scroll_view != null else 0))
		return
	_show_screen(screen_name)

func _restore_scroll(value: int) -> void:
	if scroll_view != null:
		scroll_view.scroll_vertical = maxi(0, value)

'''
if "func _handle_screen_request(" not in text:
	text = text.replace("func _show_screen(screen_name: String) -> void:\\n", handle + "func _show_screen(screen_name: String) -> void:\\n", 1)

# Do not reset vertical position when merely refreshing the same page.
text = text.replace(
	'''func _show_screen(screen_name: String) -> void:
	current_screen = screen_name
''',
	'''func _show_screen(screen_name: String) -> void:
	var previous_screen := current_screen
	current_screen = screen_name
''',
	1
)
text = text.replace(
	'''	call_deferred("_style_all_buttons")
	call_deferred("_reset_scroll")
''',
	'''	call_deferred("_style_all_buttons")
	if previous_screen != screen_name:
		call_deferred("_reset_scroll")
''',
	1
)
new_refresh = '''func _refresh_current_screen() -> void:
	if current_screen in ["life","career","adventure","family","friends","people","inventory","character","world","chronicle"]:
		var old_scroll := scroll_view.scroll_vertical if scroll_view != null else 0
		_show_screen(current_screen)
		call_deferred("_restore_scroll", old_scroll)
'''
replace_function(ui, "_refresh_current_screen", new_refresh)

# Inject a concise result banner at the top of the page the player acted from.
text = ui.read_text(encoding="utf-8")
inline_helper = '''func _inject_inline_action_feedback() -> void:
	if current_screen not in ["career","adventure","family","friends","people","inventory","character","world","chronicle"]:
		return
	var updates: Array = Game.state.get("recent_updates", [])
	if updates.is_empty():
		return
	var box := VBoxContainer.new()
	box.name = "InlineActionFeedback"
	box.add_theme_constant_override("separation", 4)
	var title := Label.new()
	title.text = "Latest"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var shown := 0
	for update in updates:
		if shown >= 3:
			break
		var line := Label.new()
		line.text = str(update)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_size_override("font_size", 17)
		box.add_child(line)
		shown += 1
	content.add_child(box)
	content.move_child(box, 0)

'''
if "func _inject_inline_action_feedback(" not in text:
	text = text.replace("func _show_main_menu() -> void:\\n", inline_helper + "func _show_main_menu() -> void:\\n", 1)
# Add feedback after the selected page function has built content.
text = text.replace(
	'''	if previous_screen != screen_name:
		call_deferred("_reset_scroll")
''',
	'''	_inject_inline_action_feedback()
	if previous_screen != screen_name:
		call_deferred("_reset_scroll")
''',
	1
)
ui.write_text(text, encoding="utf-8")

# Game actions: stay on the current page for ordinary results. Events remain
# choice-driven, then return to the page that launched them.
game = ROOT / "autoload/game.gd"
text = game.read_text(encoding="utf-8")
text = text.replace(
	'''		state["recent_updates"] = [str(eligibility.get("reason", "That activity is locked."))]
		screen_requested.emit("life")
		return
''',
	'''		state["recent_updates"] = [str(eligibility.get("reason", "That activity is locked."))]
		state_changed.emit()
		return
''',
	1
)
text = text.replace(
	'''	else:
		_commit("social_action_completed" if social_slot else "turn_completed")
		screen_requested.emit("turn_result")
''',
	'''	else:
		_commit("social_action_completed" if social_slot else "turn_completed")
		state_changed.emit()
''',
	1
)
text = text.replace(
	'''	_append_recent_updates(["You chose to move into the next year of your life."])
	_commit("quick_year_completed")
	screen_requested.emit("turn_result")
''',
	'''	_append_recent_updates(["You chose to move into the next year of your life."])
	_commit("quick_year_completed")
	state_changed.emit()
''',
	1
)
text = text.replace(
	'''	_commit("event_resolved")
	event_resolved.emit()
	if not bool(player().get("alive", true)):
		screen_requested.emit("death")
	else:
		screen_requested.emit("turn_result")
''',
	'''	_commit("event_resolved")
	event_resolved.emit()
	if not bool(player().get("alive", true)):
		screen_requested.emit("death")
	else:
		screen_requested.emit("return_from_event")
''',
	1
)
game.write_text(text, encoding="utf-8")

# The P50 possession UI contract moved intentionally from Character to the
# dedicated Inventory & Crafting category.
smoke = ROOT / "tests/runtime_smoke.gd"
st = smoke.read_text(encoding="utf-8")
st = st.replace(
	'''	main.call("_show_screen", "character")
	await process_frame
	_check(_has_text(main, "Possessions & equipment"), "P50 Character screen missing possession section")
	var locked_practice = _find_button(main, "🔒 Wooden Practice Sword • 6 gold")
	_check(locked_practice != null and bool(locked_practice.disabled), "P50 Character screen hides or enables age-locked practice sword")
	_check(_has_text(main, "Weapon • A balanced wooden sword for controlled practice rather than real fighting.
Unlock: Requires age 10."), "P50 locked item does not show exact unlock reason")
''',
	'''	main.call("_show_screen", "inventory")
	await process_frame
	_check(_has_text(main, "Inventory & Crafting"), "P89 inventory screen missing possession category")
	_check(_has_text(main, "Equipment Shop"), "P89 inventory screen missing equipment shop")
	var locked_practice = _find_button(main, "🔒 Wooden Practice Sword • 6 gold")
	_check(locked_practice != null and bool(locked_practice.disabled), "P89 inventory screen hides or enables age-locked practice sword")
	_check(_has_text(main, "A balanced wooden sword for controlled practice rather than real fighting.
Unlock: Requires age 10."), "P89 locked item does not show exact unlock reason")
''',
	1
)
smoke.write_text(st, encoding="utf-8")



# P89 updates inherited creator regressions to the responsive vertical layout.
smoke = ROOT / "tests/runtime_smoke.gd"
st = smoke.read_text(encoding="utf-8")
st = st.replace(
	'["Skin tone", "Eyes", "Brows", "Mouth", "Hairstyle", "Outfit", "Bloodline"]',
	'["Skin", "Eyes", "Brows", "Mouth", "Hair", "Outfit", "Bloodline"]'
)
smoke.write_text(st, encoding="utf-8")

qol = ROOT / "tests/qol_balance_test.gd"
if qol.exists():
	qt = qol.read_text(encoding="utf-8")
	qt = qt.replace('_has_text(main, "Hairstyle")', '_has_text(main, "Hair")')
	qt = qt.replace('"English Hairstyle control is missing"', '"English Hair control is missing"')
	qt = qt.replace(
		'preview.custom_minimum_size.x >= 200.0 and preview.custom_minimum_size.y >= 240.0',
		'preview.custom_minimum_size.x >= 180.0 and preview.custom_minimum_size.y >= 200.0'
	)
	qol.write_text(qt, encoding="utf-8")

(ROOT/"VERSION.txt").write_text("P0-P89\n",encoding="utf-8")
print("P89 mobile UI, portrait, inventory, friends and child-action hotfix applied.")
