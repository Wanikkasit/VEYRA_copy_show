extends RefCounted
## Standalone portfolio rules inspired by VEYRA's design goals.
## This is not the private P92/P93 simulation engine.

const ELEMENTS: Array[String] = ["Earth", "Water", "Wind", "Fire", "Lightning", "Wood"]
const TALENTS: Array[String] = ["Sword", "Spear", "Fist", "Magic", "Crafting", "Trade"]
const NAMES: Array[String] = ["Ari", "Elian", "Mira", "Noel", "Sora", "Tarin", "Yuna", "Zev"]
const CAREERS: Array[String] = ["Guild Scout", "Artisan", "Trader", "Caretaker"]
const ACTIVITIES: Array[String] = ["Study", "Train", "Work", "Rest"]
const ITEMS: Dictionary = {"Travel Pack": 12, "Herbal Tonic": 8, "Lucky Charm": 18}

static func create_life(gender: String, hair: int, seed_value: int, skin: int = 1) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    var element: String = ELEMENTS[rng.randi_range(0, ELEMENTS.size() - 1)]
    var talent: String = TALENTS[rng.randi_range(0, TALENTS.size() - 1)]
    return {
        "version": 2, "seed": seed_value,
        "name": NAMES[rng.randi_range(0, NAMES.size() - 1)],
        "gender": gender, "hair": clampi(hair, 0, 3), "skin": clampi(skin, 0, 2),
        "age": 0, "year": 1, "element": element, "talent": talent,
        "health": 100, "coins": 20, "renown": 0, "bond": 1,
        "knowledge": 0, "strength": 0, "craft": 0,
        "career": "Undecided", "friend": "Rowan", "friendship": 0,
        "bag": ["Worn Journal"], "history": [], "acted": false,
        "activity_used": false, "social_used": false, "ended": false, "last_result": ""
    }

static func normalize(data: Dictionary) -> Dictionary:
    var result: Dictionary = data.duplicate(true)
    var defaults: Dictionary = {
        "version": 2, "seed": 0, "skin": 1,
        "knowledge": 0, "strength": 0, "craft": 0,
        "career": "Undecided", "friend": "Rowan", "friendship": 0,
        "bag": ["Worn Journal"], "history": [], "activity_used": false, "social_used": false
    }
    for key in defaults.keys():
        if not result.has(key):
            result[key] = defaults[key]
    return result

static func stage_for_age(age: int) -> String:
    if age < 7:
        return "Childhood"
    if age < 16:
        return "Apprenticeship"
    if age < 60:
        return "Adulthood"
    return "Later Life"

static func event_for_age(age: int, year: int, data: Dictionary = {}) -> Dictionary:
    var events: Array[Dictionary] = []
    if age < 7:
        events = [
            {"title":"A Story by the Fire", "story":"Your family tells a tale of six elements and the lives they shape.",
             "choices":[
                {"text":"Ask questions about magic", "knowledge":2, "bond":1, "result":"You remember the story long after the fire fades."},
                {"text":"Listen beside your family", "bond":3, "result":"A quiet evening draws your family closer."},
                {"text":"Explore the garden", "health":3, "strength":1, "result":"You return home with muddy boots and a smile."}]},
            {"title":"The New Neighbor", "story":"A child named Rowan offers to share a handmade toy.",
             "choices":[
                {"text":"Become friends", "friendship":3, "bond":1, "result":"Rowan promises to visit again."},
                {"text":"Make a toy together", "craft":2, "friendship":1, "result":"You learn to make things with your hands."},
                {"text":"Play on your own", "health":2, "result":"You enjoy a peaceful afternoon."}]},
            {"title":"A Family Errand", "story":"There is enough time to help at home or chase a new curiosity.",
             "choices":[
                {"text":"Help with the household", "coins":3, "bond":2, "result":"Your family appreciates the help."},
                {"text":"Study an old map", "knowledge":2, "result":"A distant mountain sparks your imagination."},
                {"text":"Visit the village square", "friendship":1, "health":1, "result":"You get to know your neighbors."}]}
        ]
    elif age < 16:
        events = [
            {"title":"The Academy Notice", "story":"A mentor offers extra lessons, but your friends have plans of their own.",
             "choices":[
                {"text":"Study elemental theory", "knowledge":3, "renown":1, "result":"Your teacher notices your curiosity."},
                {"text":"Practice with a wooden sword", "strength":3, "health":-2, "result":"You practice until sunset."},
                {"text":"Help Rowan prepare for class", "friendship":3, "bond":1, "result":"Rowan is grateful for your time."}]},
            {"title":"Market Apprenticeship", "story":"A visiting merchant invites students to try honest work for a day.",
             "choices":[
                {"text":"Help at the market", "coins":6, "craft":1, "result":"You bring home a small day's wage."},
                {"text":"Watch the artisans", "craft":3, "result":"You learn how everyday tools are made."},
                {"text":"Stay and read", "knowledge":2, "health":1, "result":"You finish a chapter in peace."}]},
            {"title":"A Difficult Choice", "story":"A classmate is blamed for something they did not do.",
             "choices":[
                {"text":"Speak up fairly", "renown":2, "friendship":2, "result":"Your honesty earns quiet respect."},
                {"text":"Gather more evidence first", "knowledge":3, "result":"You learn the value of checking facts."},
                {"text":"Comfort the classmate", "bond":2, "health":1, "result":"Your kindness is remembered."}]}
        ]
    elif age < 60:
        events = [
            {"title":"Road Beyond the Town", "story":"A rumor points toward old ruins. No one knows whether the path is safe.",
             "choices":[
                {"text":"Join a cautious scout group", "strength":2, "renown":3, "health":-7, "result":"You return with notes, not treasure."},
                {"text":"Research the story at home", "knowledge":3, "result":"You separate facts from rumors."},
                {"text":"Help local farmers instead", "coins":5, "bond":2, "result":"Your neighbors appreciate reliable help."}]},
            {"title":"An Offer of Work", "story":"People in town need supplies, skilled hands, and someone willing to listen.",
             "choices":[
                {"text":"Take a paid commission", "coins":9, "craft":2, "health":-2, "result":"The commission pays fairly."},
                {"text":"Support a neighbor", "friendship":2, "bond":3, "result":"You make time for someone who needs it."},
                {"text":"Study an old technique", "knowledge":3, "health":-1, "result":"You gain a useful insight."}]},
            {"title":"A Stranger at the Gate", "story":"A traveler asks for help, but offers no proof of their story.",
             "choices":[
                {"text":"Offer food and directions", "coins":-3, "bond":3, "result":"The traveler leaves with a meal."},
                {"text":"Ask careful questions", "knowledge":2, "renown":1, "result":"You avoid jumping to conclusions."},
                {"text":"Recommend the local inn", "coins":2, "result":"You keep your distance politely."}]},
            {"title":"Community Festival", "story":"The annual festival has work to do, friends to see, and competitions to enter.",
             "choices":[
                {"text":"Enter the skill contest", "strength":2, "renown":2, "health":-3, "result":"Your effort draws applause."},
                {"text":"Run a market stall", "coins":7, "craft":1, "result":"The stall does well."},
                {"text":"Spend the day with Rowan", "friendship":3, "bond":2, "result":"You share a memorable day."}]}
        ]
    else:
        events = [
            {"title":"Passing on Wisdom", "story":"You have lived many years. What would you like others to remember?",
             "choices":[
                {"text":"Mentor the younger generation", "bond":3, "renown":2, "health":-1, "result":"Your lessons are passed forward."},
                {"text":"Write your memories", "knowledge":2, "renown":2, "result":"A small journal becomes a legacy."},
                {"text":"Enjoy a quiet evening", "health":3, "friendship":1, "result":"You find joy in a gentle routine."}]},
            {"title":"A Familiar Friend", "story":"Rowan visits. You can reminisce, advise, or simply spend time together.",
             "choices":[
                {"text":"Share stories", "friendship":3, "bond":2, "result":"Old memories feel new again."},
                {"text":"Offer gentle advice", "knowledge":1, "renown":2, "result":"Your advice may guide someone."},
                {"text":"Walk through the garden", "health":3, "result":"The garden is still beautiful."}]}
        ]
    var selected: int = posmod(year + int(data.get("seed", 0)) % 17, events.size())
    return events[selected].duplicate(true)

static func available_choices(data: Dictionary, event: Dictionary) -> Array:
    return event.get("choices", [])

static func apply_choice(data: Dictionary, choice: Dictionary) -> Dictionary:
    var result: Dictionary = normalize(data)
    if bool(result.get("acted", false)) or bool(result.get("ended", false)):
        return result
    for key in ["coins", "bond", "renown", "knowledge", "strength", "craft", "friendship"]:
        result[key] = maxi(0, int(result.get(key, 0)) + int(choice.get(key, 0)))
    result["health"] = clampi(int(result.get("health", 100)) + int(choice.get("health", 0)), 0, 100)
    result["acted"] = true
    result["last_result"] = str(choice.get("result", "You made a choice."))
    var log: Array = result.get("history", [])
    log.push_front("Age %d: %s" % [int(result["age"]), str(choice.get("text", "Decision"))])
    result["history"] = log.slice(0, 8)
    if int(result["health"]) <= 0:
        result["ended"] = true
        result["last_result"] = "Your life has ended. Your story remains."
    return result

static func activity(data: Dictionary, kind: String) -> Dictionary:
    var result: Dictionary = normalize(data)
    if bool(result.get("activity_used", false)) or bool(result.get("ended", false)) or not ACTIVITIES.has(kind):
        return result
    if kind == "Study":
        result["knowledge"] += 2
        result["last_result"] = "You spent some time studying."
    elif kind == "Train":
        result["strength"] += 2
        result["health"] = maxi(1, int(result["health"]) - 2)
        result["last_result"] = "Practice sharpened your abilities."
    elif kind == "Work":
        result["coins"] += 4 if int(result["age"]) < 16 else 8
        result["craft"] += 1
        result["last_result"] = "You completed an honest day's work."
    else:
        result["health"] = mini(100, int(result["health"]) + 8)
        result["last_result"] = "You took time to recover."
    result["activity_used"] = true
    return result

static func spend_time(data: Dictionary) -> Dictionary:
    var result: Dictionary = normalize(data)
    if bool(result.get("social_used", false)) or bool(result.get("ended", false)):
        return result
    result["friendship"] += 2
    result["bond"] += 1
    result["social_used"] = true
    result["last_result"] = "You caught up with Rowan."
    return result

static func choose_career(data: Dictionary, career: String) -> Dictionary:
    var result: Dictionary = normalize(data)
    if int(result.get("age", 0)) < 16 or str(result.get("career", "")) != "Undecided" or not CAREERS.has(career):
        return result
    result["career"] = career
    result["last_result"] = "You chose a path as a %s." % career
    return result

static func buy_item(data: Dictionary, item: String) -> Dictionary:
    var result: Dictionary = normalize(data)
    if not ITEMS.has(item) or bool(result.get("ended", false)):
        return result
    var cost: int = int(ITEMS[item])
    var bag: Array = result.get("bag", [])
    if int(result.get("coins", 0)) < cost or bag.has(item):
        return result
    result["coins"] = int(result["coins"]) - cost
    bag.append(item)
    result["bag"] = bag
    if item == "Herbal Tonic":
        result["health"] = mini(100, int(result["health"]) + 15)
    result["last_result"] = "Added %s to your belongings." % item
    return result

static func advance_year(data: Dictionary) -> Dictionary:
    var result: Dictionary = normalize(data)
    if not bool(result.get("acted", false)) or bool(result.get("ended", false)):
        return result
    result["age"] = int(result.get("age", 0)) + 1
    result["year"] = int(result.get("year", 1)) + 1
    result["acted"] = false
    result["activity_used"] = false
    result["social_used"] = false
    if int(result["age"]) >= 65:
        result["health"] = maxi(0, int(result["health"]) - 1)
    if int(result["age"]) >= 85 or int(result["health"]) <= 0:
        result["ended"] = true
        result["last_result"] = "A life completed. Every choice is part of your story."
    return result

static func skip_to_adult(data: Dictionary) -> Dictionary:
    var result: Dictionary = normalize(data)
    if int(result.get("age", 0)) >= 16 or bool(result.get("ended", false)):
        return result
    result["age"] = 16
    result["year"] = 17
    result["acted"] = false
    result["activity_used"] = false
    result["social_used"] = false
    result["last_result"] = "Demo shortcut: adulthood unlocked. Earlier years were skipped."
    return result
