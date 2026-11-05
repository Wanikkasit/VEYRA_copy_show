class_name CareerSystem
extends RefCounted

const WorldSimulatorClass = preload("res://core/world/world_simulator.gd")
const EducationSystemClass = preload("res://core/life/education_system.gd")
const HealthSystemClass = preload("res://core/health/health_system.gd")
const JusticeSystemClass = preload("res://core/world/justice_system.gd")
const PoliticalSystemClass = preload("res://core/world/political_system.gd")

const MIN_RETIRE_AGE := 55
const NPC_RETIRE_CHECK_AGE := 58
const NPC_FORCED_RETIRE_AGE := 72

const CAREERS := {
	"farmer": {"label": "Farmer", "skill": "farming", "income": 11, "employer": "Independent holding", "min_education": 0},
	"healer": {"label": "Healer", "skill": "medicine", "income": 15, "employer": "Willow House of Physic", "min_education": 30},
	"merchant": {"label": "Merchant", "skill": "commerce", "income": 16, "employer": "Rivergate trade network", "min_education": 0},
	"scholar": {"label": "Scholar", "skill": "research", "income": 13, "employer": "Sixfold Collegium", "min_education": 38},
	"cook": {"label": "Cook", "skill": "cooking", "income": 12, "employer": "Local household or inn", "min_education": 0},
	"teacher": {"label": "Teacher", "skill": "teaching", "income": 13, "employer": "Local school", "min_education": 34},
	"guard": {"label": "Guard", "skill": "sword", "income": 14, "employer": "Graywood Wardens", "min_education": 0},
	"academy_student": {"label": "Academy Student", "skill": "mana_control", "income": -4, "employer": "Sixfold Collegium", "min_education": 42},
	"underworld_runner": {"label": "Underworld Runner", "skill": "commerce", "income": 18, "employer": "Black Lantern Ring", "min_education": 0}
}

const RANK_LABELS := ["Novice", "Established", "Senior", "Expert", "Master"]

static func ensure_player_fields(player: Dictionary) -> void:
	ensure_character_fields(player)
	for key in ["farming"]:
		if not player.get("skills", {}).has(key):
			player["skills"][key] = 0
	if not player.get("talents", {}).has("farming"):
		player["talents"]["farming"] = {"value": 50, "discovered": true}

static func ensure_character_fields(character: Dictionary) -> void:
	if typeof(character.get("career_data", null)) != TYPE_DICTIONARY:
		character["career_data"] = {}
	var data: Dictionary = character["career_data"]
	data["experience"] = maxi(0, int(data.get("experience", 0)))
	data["rank"] = clampi(int(data.get("rank", 0)), 0, RANK_LABELS.size() - 1)
	data["started_year"] = int(data.get("started_year", -1))
	data["performance"] = clampi(int(data.get("performance", 50)), 0, 100)
	data["lifetime_earnings"] = maxi(0, int(data.get("lifetime_earnings", 0)))
	if typeof(data.get("history", null)) != TYPE_ARRAY:
		data["history"] = []
	if typeof(data.get("past_careers", null)) != TYPE_ARRAY:
		data["past_careers"] = []
	data["retired"] = bool(data.get("retired", str(character.get("career", "")) == "retired"))
	data["retired_year"] = int(data.get("retired_year", -1))
	data["former_career"] = str(data.get("former_career", ""))
	data["former_rank"] = clampi(int(data.get("former_rank", 0)), 0, RANK_LABELS.size() - 1)
	data["former_employer"] = str(data.get("former_employer", ""))
	var career_id := str(character.get("career", ""))
	if CAREERS.has(career_id):
		data["employer"] = str(data.get("employer", CAREERS[career_id].get("employer", "Independent")))
	else:
		data["employer"] = str(data.get("employer", ""))

static func opportunities(state: Dictionary) -> Array[Dictionary]:
	var player := _player(state)
	ensure_player_fields(player)
	EducationSystemClass.ensure_character(state, player)
	if int(player.get("age", 0)) < 18:
		return []
	var scored: Array[Dictionary] = []
	for raw_id in CAREERS.keys():
		var id := str(raw_id)
		var eligible := _eligible(player, id)
		var legal_eligibility: Dictionary = JusticeSystemClass.career_eligibility(state, id)
		if not eligible or not bool(legal_eligibility.get("available", false)):
			continue
		var definition: Dictionary = CAREERS[id]
		var skill := str(definition.get("skill", ""))
		var talent := int(player.get("talents", {}).get(skill, {}).get("value", 45))
		var existing := int(player.get("skills", {}).get(skill, 0))
		var education_bonus := EducationSystemClass.career_preparation(player, id)
		var score := talent + existing * 2 + education_bonus
		if id == "farmer": score += 4
		scored.append({"id": id, "score": score})
	scored.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))
	var out: Array[Dictionary] = []
	for row in scored:
		var id := str(row.get("id", ""))
		var item: Dictionary = CAREERS[id].duplicate(true)
		item["id"] = id
		item["fit_score"] = int(row.get("score", 0))
		item["education_required"] = int(CAREERS[id].get("min_education", 0))
		out.append(item)
	return out

static func locked_opportunities(state: Dictionary) -> Array[Dictionary]:
	var player := _player(state)
	if player.is_empty() or int(player.get("age", 0)) < 18:
		return []
	EducationSystemClass.ensure_character(state, player)
	var out: Array[Dictionary] = []
	for raw_id in CAREERS.keys():
		var id := str(raw_id)
		if id == "underworld_runner" and not bool(player.get("flags", {}).get("underworld_contact", false)):
			continue
		var legal_eligibility: Dictionary = JusticeSystemClass.career_eligibility(state, id)
		if _eligible(player, id) and bool(legal_eligibility.get("available", false)):
			continue
		var item: Dictionary = CAREERS[id].duplicate(true)
		item["id"] = id
		item["reason"] = _lock_reason(player, id) if not _eligible(player, id) else str(legal_eligibility.get("reason", "Legal restrictions block this path."))
		out.append(item)
	return out

static func choose(state: Dictionary, career_id: String) -> bool:
	if not CAREERS.has(career_id):
		return false
	var player := _player(state)
	ensure_player_fields(player)
	EducationSystemClass.ensure_character(state, player)
	if int(player.get("age", 0)) < 18 or not _eligible(player, career_id):
		return false
	if not bool(JusticeSystemClass.career_eligibility(state, career_id).get("available", false)):
		return false
	var old := str(player.get("career", "young_adult"))
	var old_data: Dictionary = player.get("career_data", {}).duplicate(true)
	var past: Array = old_data.get("past_careers", []).duplicate(true) if typeof(old_data.get("past_careers", null)) == TYPE_ARRAY else []
	if CAREERS.has(old) and old != career_id and not bool(old_data.get("retired", false)):
		past.append(_career_snapshot(old, old_data, int(state.get("calendar", {}).get("year", 0)), "changed"))
	player["career"] = career_id
	player["career_data"] = {
		"experience": 0,
		"rank": 0,
		"started_year": int(state.get("calendar", {}).get("year", 0)),
		"performance": 50,
		"lifetime_earnings": 0,
		"employer": str(CAREERS[career_id].get("employer", "Independent")),
		"history": [{"year": int(state.get("calendar", {}).get("year", 0)), "kind": "started", "career": career_id}],
		"past_careers": past,
		"retired": false,
		"retired_year": -1,
		"former_career": "",
		"former_rank": 0,
		"former_employer": ""
	}
	state["chronicle"].append({
		"year": int(state.get("calendar", {}).get("year", 0)),
		"age": int(player.get("age", 0)),
		"category": "career",
		"title": "A New Path",
		"summary": "%s left the %s path and began life as %s." % [str(player.get("first_name", "You")), old.replace("_", " "), str(CAREERS[career_id]["label"])]
	})
	return true

static func work_turn(state: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var player := _player(state)
	ensure_player_fields(player)
	if str(player.get("career", "")) == "retired" or bool(player.get("career_data", {}).get("retired", false)):
		return {"money": 0, "skill": "", "skill_gain": 0, "xp": 0, "promoted": false, "rank": int(player.get("career_data", {}).get("rank", 0))}
	var career_id := str(player.get("career", "young_adult"))
	if not CAREERS.has(career_id):
		return {"money": 6, "skill": "", "skill_gain": 0, "xp": 2, "promoted": false}
	var definition: Dictionary = CAREERS[career_id]
	var skill := str(definition.get("skill", ""))
	var talent := int(player.get("talents", {}).get(skill, {}).get("value", 45))
	var gain := 1 + int(talent / 35)
	if not skill.is_empty():
		player["skills"][skill] = int(player.get("skills", {}).get(skill, 0)) + gain
	var rank_before := int(player["career_data"].get("rank", 0))
	var base_value := int(definition.get("income", 0))
	var rank_multiplier := 1.0 + float(rank_before) * 0.12
	# Rank progression increases earnings, never tuition/cost magnitude.
	var base_income := base_value
	if base_value > 0:
		base_income = int(round(float(base_value) * rank_multiplier))
	var world_multiplier := WorldSimulatorClass.career_income_multiplier(state, player, career_id)
	var health_penalty := HealthSystemClass.work_penalty(player)
	var health_multiplier := clampf(1.0 - float(health_penalty) / 100.0, 0.70, 1.0)
	var equipment_quality := int(player.get("equipment_bonuses", {}).get("work_quality", 0))
	var equipment_multiplier := 1.0 + float(equipment_quality) * 0.02
	var income := int(round(float(base_income) * world_multiplier * health_multiplier * equipment_multiplier))
	state["money"] = maxi(0, int(state.get("money", 0)) + income)
	var xp_gain := maxi(1, 4 + gain + int(EducationSystemClass.career_preparation(player, career_id) / 18) - int(health_penalty / 5))
	player["career_data"]["experience"] = int(player["career_data"].get("experience", 0)) + xp_gain
	player["career_data"]["lifetime_earnings"] = int(player["career_data"].get("lifetime_earnings", 0)) + maxi(0, income)
	var performance_delta := 1 + int(talent / 40) + int(equipment_quality / 2) + rng.randi_range(-1, 2) - int(health_penalty / 4)
	player["career_data"]["performance"] = clampi(int(player["career_data"].get("performance", 50)) + performance_delta, 0, 100)
	_maybe_promote(player)
	var rank_after := int(player["career_data"].get("rank", 0))
	if rank_after > rank_before:
		player["career_data"]["history"].append({"year": int(state.get("calendar", {}).get("year", 0)), "kind": "promotion", "rank": rank_after})
		state["chronicle"].append({
			"year": int(state.get("calendar", {}).get("year", 0)),
			"age": int(player.get("age", 0)),
			"category": "career",
			"title": "Career Promotion",
			"summary": "%s advanced to %s %s." % [str(player.get("first_name", "You")), rank_label(rank_after), str(definition.get("label", "worker"))]
		})
	return {
		"money": income,
		"base_money": base_income,
		"world_multiplier": world_multiplier,
		"health_penalty": health_penalty,
		"equipment_quality": equipment_quality,
		"skill": skill,
		"skill_gain": gain,
		"xp": xp_gain,
		"promoted": rank_after > rank_before,
		"rank": rank_after
	}

static func simulate_npc_year(state: Dictionary, rng: RandomNumberGenerator) -> Array[String]:
	var updates: Array[String] = []
	var player: Dictionary = _player(state)
	var player_family_id := str(player.get("family_id", ""))
	for raw_id in state.get("characters", {}).keys():
		var id := str(raw_id)
		if id == str(state.get("player_id", "")):
			continue
		var npc: Dictionary = state["characters"].get(id, {})
		if npc.is_empty() or not bool(npc.get("alive", true)) or int(npc.get("age", 0)) < 18:
			continue
		var career_id := str(npc.get("career", ""))
		if not CAREERS.has(career_id):
			continue
		ensure_character_fields(npc)
		if _should_npc_retire(npc, rng):
			var retirement := retire(state, id, "age_or_health")
			if bool(retirement.get("ok", false)) and (str(npc.get("family_id", "")) == player_family_id or bool(retirement.get("left_office", false))):
				updates.append(str(retirement.get("message", "%s retired." % str(npc.get("first_name", "Someone")))))
			continue
		EducationSystemClass.ensure_character(state, npc)
		var data: Dictionary = npc["career_data"]
		if int(data.get("started_year", -1)) < 0:
			data["started_year"] = int(state.get("calendar", {}).get("year", 0))
			data["employer"] = str(CAREERS[career_id].get("employer", "Independent"))
		var before_rank := int(data.get("rank", 0))
		var skill := str(CAREERS[career_id].get("skill", ""))
		var talent := int(npc.get("talents", {}).get(skill, {}).get("value", 45))
		var health_penalty := HealthSystemClass.work_penalty(npc)
		var xp_gain := maxi(1, 4 + int(talent / 30) + int(EducationSystemClass.career_preparation(npc, career_id) / 20) - int(health_penalty / 5))
		data["experience"] = int(data.get("experience", 0)) + xp_gain
		data["performance"] = clampi(int(data.get("performance", 50)) + rng.randi_range(-2, 3) - int(health_penalty / 4), 0, 100)
		_maybe_promote(npc)
		var household_id := str(npc.get("household_id", ""))
		if state.get("households", {}).has(household_id):
			var annual_contribution := maxi(0, int(round(float(int(CAREERS[career_id].get("income", 0)) * 2 + int(data.get("rank", 0)) * 3) * clampf(1.0 - float(health_penalty) / 100.0, 0.70, 1.0))))
			state["households"][household_id]["shared_wealth"] = maxi(0, int(state["households"][household_id].get("shared_wealth", 0)) + annual_contribution)
			data["lifetime_earnings"] = int(data.get("lifetime_earnings", 0)) + annual_contribution
		if int(data.get("rank", 0)) > before_rank and not player_family_id.is_empty() and str(npc.get("family_id", "")) == player_family_id:
			updates.append("%s advanced to %s %s." % [str(npc.get("first_name", "A relative")), rank_label(int(data.get("rank", 0))), str(CAREERS[career_id].get("label", "worker"))])
	return updates

static func retirement_eligibility(character: Dictionary) -> Dictionary:
	if character.is_empty() or not bool(character.get("alive", true)):
		return {"available": false, "reason": "Only a living character can retire."}
	ensure_character_fields(character)
	var career_id := str(character.get("career", ""))
	if career_id == "retired" or bool(character.get("career_data", {}).get("retired", false)):
		return {"available": false, "reason": "Already retired. Choose a career path to return to work."}
	if not CAREERS.has(career_id):
		return {"available": false, "reason": "Choose an adult career before retiring from one."}
	var age := int(character.get("age", 0))
	if age < MIN_RETIRE_AGE:
		return {"available": false, "reason": "Retirement unlocks at age %d." % MIN_RETIRE_AGE}
	return {"available": true, "reason": ""}

static func retire(state: Dictionary, character_id: String = "", reason: String = "retirement") -> Dictionary:
	var id := character_id if not character_id.is_empty() else str(state.get("player_id", ""))
	var character: Dictionary = state.get("characters", {}).get(id, {})
	var eligibility := retirement_eligibility(character)
	if not bool(eligibility.get("available", false)):
		return {"ok": false, "message": str(eligibility.get("reason", "Retirement is not available."))}
	var year := int(state.get("calendar", {}).get("year", 0))
	var old_id := str(character.get("career", ""))
	var data: Dictionary = character["career_data"]
	var old_label := label(old_id)
	data["past_careers"].append(_career_snapshot(old_id, data, year, "retired"))
	while data["past_careers"].size() > 16:
		data["past_careers"].pop_front()
	data["retired"] = true
	data["retired_year"] = year
	data["former_career"] = old_id
	data["former_rank"] = int(data.get("rank", 0))
	data["former_employer"] = str(data.get("employer", ""))
	data["history"].append({"year": year, "kind": "retired", "career": old_id, "reason": reason})
	character["career"] = "retired"
	var office_result: Dictionary = PoliticalSystemClass.vacate_office(state, id, "retirement")
	var display := str(character.get("display_name", character.get("first_name", "Someone")))
	var message := "%s retired from a career as %s." % [display, old_label]
	if bool(office_result.get("ok", false)):
		message += " They also stepped down as %s." % str(office_result.get("title", "a public officer"))
	if id == str(state.get("player_id", "")):
		state["chronicle"].append({"year": year, "age": int(character.get("age", 0)), "category": "career", "title": "Retirement", "summary": "You retired from life as %s. Work ended, but the rest of your life did not." % old_label})
	return {"ok": true, "message": message, "former_career": old_id, "former_label": old_label, "left_office": bool(office_result.get("ok", false))}

static func _career_snapshot(career_id: String, data: Dictionary, end_year: int, reason: String) -> Dictionary:
	return {"career": career_id, "label": label(career_id), "started_year": int(data.get("started_year", -1)), "ended_year": end_year, "rank": int(data.get("rank", 0)), "rank_label": rank_label(int(data.get("rank", 0))), "lifetime_earnings": int(data.get("lifetime_earnings", 0)), "employer": str(data.get("employer", "")), "reason": reason}

static func _should_npc_retire(npc: Dictionary, rng: RandomNumberGenerator) -> bool:
	var age := int(npc.get("age", 0))
	if age < NPC_RETIRE_CHECK_AGE:
		return false
	if age >= NPC_FORCED_RETIRE_AGE:
		return true
	var health := int(npc.get("health", 100))
	var chance := 0.08 + float(age - NPC_RETIRE_CHECK_AGE) * 0.035 + float(maxi(0, 60 - health)) * 0.008
	return rng.randf() < clampf(chance, 0.08, 0.75)

static func label(career_id: String) -> String:
	if CAREERS.has(career_id): return str(CAREERS[career_id]["label"])
	return career_id.replace("_", " ").capitalize()

static func rank_label(rank: int) -> String:
	return str(RANK_LABELS[clampi(rank, 0, RANK_LABELS.size() - 1)])

static func career_summary(character: Dictionary) -> Dictionary:
	ensure_character_fields(character)
	var career_id := str(character.get("career", ""))
	var data: Dictionary = character["career_data"]
	var is_retired := career_id == "retired" or bool(data.get("retired", false))
	var former_id := str(data.get("former_career", ""))
	var shown_label := "Retired" if is_retired else label(career_id)
	var shown_rank := "Former %s %s" % [rank_label(int(data.get("former_rank", 0))), label(former_id)] if is_retired and CAREERS.has(former_id) else rank_label(int(data.get("rank", 0)))
	return {
		"career": career_id,
		"label": shown_label,
		"rank": int(data.get("rank", 0)),
		"rank_label": shown_rank,
		"experience": int(data.get("experience", 0)),
		"performance": int(data.get("performance", 50)),
		"employer": str(data.get("former_employer", "")) if is_retired else str(data.get("employer", "")),
		"lifetime_earnings": int(data.get("lifetime_earnings", 0)),
		"retired": is_retired,
		"retired_year": int(data.get("retired_year", -1)),
		"former_career": former_id,
		"past_careers": data.get("past_careers", []).duplicate(true)
	}

static func _eligible(player: Dictionary, career_id: String) -> bool:
	if not CAREERS.has(career_id):
		return false
	if career_id == "academy_student" and not _academy_possible(player):
		return false
	if career_id == "underworld_runner" and not bool(player.get("flags", {}).get("underworld_contact", false)):
		return false
	var required := int(CAREERS[career_id].get("min_education", 0))
	return EducationSystemClass.attainment_score(player) >= required

static func _lock_reason(player: Dictionary, career_id: String) -> String:
	if career_id == "academy_student" and not _academy_possible(player):
		return "Requires magical affinity or stronger mana/research aptitude."
	if career_id == "underworld_runner" and not bool(player.get("flags", {}).get("underworld_contact", false)):
		return "This path is hidden until you have an underworld contact."
	var required := int(CAREERS[career_id].get("min_education", 0))
	var current := EducationSystemClass.attainment_score(player)
	if current < required:
		return "Education %d/%d required." % [current, required]
	return "Not currently eligible."

static func _maybe_promote(character: Dictionary) -> void:
	var xp := int(character.get("career_data", {}).get("experience", 0))
	var rank := int(character.get("career_data", {}).get("rank", 0))
	var performance := int(character.get("career_data", {}).get("performance", 50))
	var thresholds := [20, 55, 110, 190]
	while rank < thresholds.size() and xp >= int(thresholds[rank]) and performance >= 35 + rank * 5:
		rank += 1
	character["career_data"]["rank"] = rank

static func _academy_possible(player: Dictionary) -> bool:
	for affinity_variant in player.get("affinities", {}).values():
		if typeof(affinity_variant) == TYPE_DICTIONARY and bool(affinity_variant.get("has_affinity", false)):
			return true
	var mana := int(player.get("talents", {}).get("mana_control", {}).get("value", 0))
	var research := int(player.get("talents", {}).get("research", {}).get("value", 0))
	return mana >= 45 or research >= 55

static func _player(state: Dictionary) -> Dictionary:
	return state.get("characters", {}).get(str(state.get("player_id", "")), {})