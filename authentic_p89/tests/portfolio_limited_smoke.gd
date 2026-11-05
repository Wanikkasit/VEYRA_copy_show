extends SceneTree
## Test harness for existing VEYRA P89 game code; no gameplay reimplementation.
const Portrait = preload("res://ui/widgets/portrait_widget.gd")

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var db: Node = root.get_node_or_null("EventDB")
    if db == null:
        printerr("VEYRA_LIMITED_FAIL: EventDB autoload missing")
        quit(2)
        return
    var events: Dictionary = db.get("events")
    if events.size() != 348:
        printerr("VEYRA_LIMITED_FAIL: expected original subset of 348, got " + str(events.size()))
        quit(2)
        return
    var portrait: Control = Portrait.new()
    portrait.custom_minimum_size = Vector2(200, 220)
    root.add_child(portrait)
    await process_frame
    var ready: bool = portrait.debug_asset_ready()
    portrait.set_character({"gender": "Woman", "age": 23, "appearance": {}})
    await process_frame
    if not ready or portrait.debug_variant_texture() == null:
        printerr("VEYRA_LIMITED_FAIL: authentic P89 portrait layers failed to load")
        quit(2)
        return
    var image: Image = portrait.debug_variant_texture().get_image()
    if image.get_width() != 160 or image.get_height() != 176:
        printerr("VEYRA_LIMITED_FAIL: portrait art native dimensions changed")
        quit(2)
        return
    print("VEYRA_LIMITED_PASS: authentic_source=P89 events=348 portrait=160x176")
    quit(0)