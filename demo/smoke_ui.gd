extends SceneTree
## Runtime UI smoke: construct the game and visit each visible tab headlessly.
const MainScene = preload("res://main.tscn")
const Rules = preload("res://demo_rules.gd")

func _initialize() -> void:
    call_deferred("_exercise")

func _exercise() -> void:
    var game: Node = MainScene.instantiate()
    root.add_child(game)
    await process_frame
    game.set("state", Rules.create_life("Woman", 2, 998, 1))
    for page in ["Life", "People", "Activities", "Bag"]:
        game.set("page", page)
        game.call("_show_game")
    var life: Dictionary = game.get("state")
    var event: Dictionary = Rules.event_for_age(int(life["age"]), int(life["year"]), life)
    game.set("state", Rules.apply_choice(life, event["choices"][0]))
    game.set("page", "Life")
    game.call("_show_game")
    game.set("state", Rules.skip_to_adult(game.get("state")))
    game.set("page", "Activities")
    game.call("_show_game")
    await process_frame
    print("VEYRA_UI_SMOKE_PASS_V02")
    quit(0)
