from pathlib import Path

ROOT = Path("game")
UI = ROOT / "ui/main.gd"

def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old in text:
        return text.replace(old, new, 1)
    if new in text:
        return text
    raise SystemExit(f"P89 finalizer missing anchor: {label}")

text = UI.read_text(encoding="utf-8")

# System-triggered routing should not make ordinary actions jump between pages.
text = replace_once(
    text,
    "Game.screen_requested.connect(_show_screen)",
    "Game.screen_requested.connect(_handle_screen_request)",
    "screen request connection",
)

if 'var _event_return_screen := "life"' not in text:
    text = replace_once(
        text,
        'var current_screen := "menu"\n',
        'var current_screen := "menu"\nvar _event_return_screen := "life"\nvar _event_return_scroll := 0\n',
        "event return state",
    )

handler = '''func _handle_screen_request(screen_name: String) -> void:
	var gameplay_pages := ["life","career","adventure","family","friends","people","inventory","character","world","chronicle"]
	var old_scroll := scroll_view.scroll_vertical if scroll_view != null else 0

	if screen_name == "event":
		if current_screen != "event":
			_event_return_screen = current_screen if current_screen in gameplay_pages else "life"
			_event_return_scroll = old_scroll
		_show_screen("event")
		return

	if screen_name == "return_from_event":
		var return_target := _event_return_screen if _event_return_screen in gameplay_pages else "life"
		_show_screen(return_target)
		call_deferred("_restore_scroll", _event_return_scroll)
		return

	if screen_name == "turn_result" or screen_name in gameplay_pages:
		# Navigation buttons call _show_screen() directly. Signals are automatic
		# outcomes, so keep the player on the page where the action was taken.
		var target := current_screen if current_screen in gameplay_pages else ("life" if screen_name == "turn_result" else screen_name)
		_show_screen(target)
		call_deferred("_restore_scroll", old_scroll)
		return

	# Combat, death, birth reveal and other genuinely different states may open
	# their own views.
	_show_screen(screen_name)

func _restore_scroll(value: int) -> void:
	if scroll_view != null:
		scroll_view.scroll_vertical = maxi(0, value)

'''
if "func _handle_screen_request(" not in text:
    anchor = "func _show_screen(screen_name: String) -> void:\n"
    if anchor not in text:
        raise SystemExit("P89 finalizer missing _show_screen")
    text = text.replace(anchor, handler + anchor, 1)

text = replace_once(
    text,
    '''func _show_screen(screen_name: String) -> void:
	current_screen = screen_name
''',
    '''func _show_screen(screen_name: String) -> void:
	var previous_screen := current_screen
	current_screen = screen_name
''',
    "show screen previous state",
)

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
    anchor = "func _show_main_menu() -> void:\n"
    if anchor not in text:
        raise SystemExit("P89 finalizer missing main menu anchor")
    text = text.replace(anchor, inline_helper + anchor, 1)

text = replace_once(
    text,
    '''	call_deferred("_style_all_buttons")
	call_deferred("_reset_scroll")
''',
    '''	call_deferred("_style_all_buttons")
	_inject_inline_action_feedback()
	if previous_screen != screen_name:
		call_deferred("_reset_scroll")
''',
    "screen footer routing",
)

# The current refresh function already preserves vertical position, but it
# depends on _restore_scroll added by this finalizer.
if 'func _refresh_current_screen() -> void:' not in text:
    raise SystemExit("P89 finalizer missing refresh function")

# Hard guarantees for the user's mobile navigation contract.
required = [
    'horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED',
    'func _handle_screen_request(',
    'func _restore_scroll(',
    'func _inject_inline_action_feedback(',
    'Game.screen_requested.connect(_handle_screen_request)',
    'CreatorAppearanceTwoColumnGrid',
    'CreatorLongFields',
    'CreatorPreviewHolder',
]
for token in required:
    if token not in text:
        raise SystemExit(f"P89 finalizer contract missing: {token}")

if 'Game.screen_requested.connect(_show_screen)' in text:
    raise SystemExit("P89 direct screen-request page hopping still connected")

UI.write_text(text, encoding="utf-8")
print("P89 final mobile routing applied: vertical-only + inline action feedback + event return.")
