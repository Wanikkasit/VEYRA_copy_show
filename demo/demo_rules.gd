extends RefCounted
## Portfolio-only life-cycle slice. The private game's rule engine is NOT included.

const ELEMENTS: Array[String] = ["Earth", "Water", "Wind", "Fire", "Lightning", "Wood"]
const TALENTS: Array[String] = ["Sword", "Spear", "Fist", "Magic", "Crafting", "Trade"]
const NAMES: Array[String] = ["Ari", "Elian", "Mira", "Noel", "Sora", "Tarin", "Yuna", "Zev"]

static func create_life(gender: String, hair: int, seed_value: int) -> Dictionary:
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_value
    return {
        "name": NAMES[rng.randi_range(0, NAMES.size() - 1)],
        "gender": gender, "hair": hair, "age": 0, "year": 1,
        "element": ELEMENTS[rng.randi_range(0, ELEMENTS.size() - 1)],
        "talent": TALENTS[rng.randi_range(0, TALENTS.size() - 1)],
        "health": 100, "coins": 20, "renown": 0, "bond": 0,
        "acted": false, "ended": false, "last_result": ""
    }

static func event_for_age(age: int, year: int) -> Dictionary:
    var events: Array[Dictionary] = []
    if age < 7:
        events = [
            {"title":"A Warm Home","story":"Your family shares stories of the world beyond your village.",
             "choices":[{"text":"Listen and learn","coins":0,"bond":2,"renown":0,"health":0},
                        {"text":"Play outside","coins":0,"bond":0,"renown":0,"health":2},
                        {"text":"Help with a small chore","coins":2,"bond":1,"renown":0,"health":0}]},
            {"title":"A New Friend","story":"Another child invites you to play.",
             "choices":[{"text":"Make a new friend","coins":0,"bond":2,"renown":0,"health":0},
                        {"text":"Practice alone","coins":0,"bond":0,"renown":1,"health":0}]}
        ]
    elif age < 16:
        events = [
            {"title":"A Choice at School","story":"A mentor offers an extra lesson after class.",
             "choices":[{"text":"Study the six elements","coins":0,"bond":0,"renown":2,"health":0},
                        {"text":"Help another student","coins":0,"bond":3,"renown":0,"health":0},
                        {"text":"Rest at home","coins":0,"bond":0,"renown":0,"health":5}]},
            {"title":"Market Day","story":"A trader visits your town with unfamiliar goods.",
             "choices":[{"text":"Take a small job","coins":5,"bond":0,"renown":0,"health":-1},
                        {"text":"Talk to visitors","coins":0,"bond":2,"renown":1,"health":0}]}
        ]
    elif age < 60:
        events = [
            {"title":"Paths of Adulthood","story":"A local guild is looking for volunteers. You can also choose a quiet life.",
             "choices":[{"text":"Join a training mission","coins":4,"bond":0,"renown":3,"health":-8},
                        {"text":"Work at the market","coins":8,"bond":0,"renown":0,"health":-2},
                        {"text":"Spend time with family","coins":-2,"bond":4,"renown":0,"health":2}]},
            {"title":"A Traveler in Need","story":"A traveler asks for help near the road.",
             "choices":[{"text":"Offer supplies","coins":-4,"bond":3,"renown":1,"health":0},
                        {"text":"Escort them to town","coins":2,"bond":1,"renown":3,"health":-6},
                        {"text":"Continue your peaceful day","coins":1,"bond":0,"renown":0,"health":2}]}
        ]
    else:
        events = [
            {"title":"Passing on Wisdom","story":"You can teach others, enjoy retirement, or write your story.",
             "choices":[{"text":"Mentor the young","coins":0,"bond":3,"renown":2,"health":-1},
                        {"text":"Rest with loved ones","coins":0,"bond":2,"renown":0,"health":4},
                        {"text":"Write your memoir","coins":-1,"bond":0,"renown":3,"health":-1}]}
        ]
    return events[year % events.size()]

static func apply_choice(data: Dictionary, choice: Dictionary) -> Dictionary:
    var result: Dictionary = data.duplicate(true)
    if bool(result.get("acted", false)) or bool(result.get("ended", false)):
        return result
    for key in ["coins", "bond", "renown"]:
        result[key] = maxi(0, int(result.get(key, 0)) + int(choice.get(key, 0)))
    result["health"] = clampi(int(result.get("health", 100)) + int(choice.get("health", 0)), 0, 100)
    result["acted"] = true
    result["last_result"] = str(choice.get("text", "Choice made")) + " — your story changes."
    if int(result["health"]) == 0:
        result["ended"] = true
        result["last_result"] = "Your life has ended. Start a new life to play again."
    return result

static func advance_year(data: Dictionary) -> Dictionary:
    var result: Dictionary = data.duplicate(true)
    if not bool(result.get("acted", false)) or bool(result.get("ended", false)):
        return result
    result["age"] = int(result.get("age", 0)) + 1
    result["year"] = int(result.get("year", 1)) + 1
    result["acted"] = false
    if int(result["age"]) >= 85:
        result["ended"] = true
        result["last_result"] = "A life completed. Your choices shaped its story."
    return result
