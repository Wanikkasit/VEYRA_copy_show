class_name FamilySystem
extends RefCounted

static func ensure_state_fields(state: Dictionary) -> void:
	if not state.has("pregnancies"): state["pregnancies"] = []
	if not state.has("adoption_plans"): state["adoption_plans"] = []

static func marry_player(state: Dictionary, target_id: String) -> bool:
	var player := _player(state)
	var target: Dictionary = state.get("characters", {}).get(target_id, {})
	if player.is_empty() or target.is_empty(): return false
	if int(player.get("age", 0)) < 18 or int(target.get("age", 0)) < 18: return false
	var rel := RelationshipUtils.ensure_relationship(state, str(player["id"]), target_id)
	if "partner" not in rel.get("roles", []): return false
	RelationshipUtils.remove_role(rel, "partner")
	RelationshipUtils.add_role(rel, "spouse")
	rel["flags"]["married_year"] = int(state.get("calendar", {}).get("year", 0))
	rel["affection"] = min(100, int(rel.get("affection", 0)) + 8)
	rel["trust"] = min(100, int(rel.get("trust", 0)) + 8)
	_merge_households(state, player, target)
	state["chronicle"].append({
		"year": int(state.get("calendar", {}).get("year", 0)),
		"age": int(player.get("age", 0)),
		"category": "family",
		"title": "Marriage",
		"summary": "%s and %s married." % [str(player.get("display_name", "You")), str(target.get("display_name", "your partner"))]
	})
	return true

static func can_plan_biological_child(state: Dictionary) -> bool:
	var spouse := spouse_of_player(state)
	if spouse.is_empty(): return false
	var player := _player(state)
	if int(player.get("age", 0)) < 18 or int(spouse.get("age", 0)) < 18: return false
	var genders := [str(player.get("gender", "")), str(spouse.get("gender", ""))]
	if "Woman" not in genders or "Man" not in genders: return false
	var woman := player if str(player.get("gender", "")) == "Woman" else spouse
	if int(woman.get("age", 0)) > 45: return false
	if _has_active_family_plan(state): return false
	return true

static func plan_biological_child(state: Dictionary) -> bool:
	ensure_state_fields(state)
	if not can_plan_biological_child(state): return false
	var player := _player(state)
	var spouse := spouse_of_player(state)
	var carrier := player if str(player.get("gender", "")) == "Woman" else spouse
	state["pregnancies"].append({
		"parent_a": str(player["id"]),
		"parent_b": str(spouse["id"]),
		"carrier_id": str(carrier["id"]),
		"due_turn": int(state.get("calendar", {}).get("absolute_turn", 0)) + 3,
		"status": "active"
	})
	return true

static func plan_adoption(state: Dictionary) -> bool:
	ensure_state_fields(state)
	var spouse := spouse_of_player(state)
	if spouse.is_empty() or _has_active_family_plan(state): return false
	state["adoption_plans"].append({
		"parent_a": str(state.get("player_id", "")),
		"parent_b": str(spouse["id"]),
		"due_turn": int(state.get("calendar", {}).get("absolute_turn", 0)) + 2,
		"status": "active"
	})
	return true

static func advance_turn(state: Dictionary) -> Array[String]:
	ensure_state_fields(state)
	var updates: Array[String] = []
	var now := int(state.get("calendar", {}).get("absolute_turn", 0))
	for record in state["pregnancies"]:
		if str(record.get("status", "")) != "active" or now < int(record.get("due_turn", 999999)): continue
		var child := _create_player_child(state, str(record.get("parent_a", "")), str(record.get("parent_b", "")), false)
		record["status"] = "completed"
		if not child.is_empty():
			updates.append("A child, %s, was born into your household." % str(child.get("first_name", "")))
			_append_birth_chronicle(state, child, false)
	for record in state["adoption_plans"]:
		if str(record.get("status", "")) != "active" or now < int(record.get("due_turn", 999999)): continue
		var child := _create_player_child(state, str(record.get("parent_a", "")), str(record.get("parent_b", "")), true)
		record["status"] = "completed"
		if not child.is_empty():
			updates.append("You welcomed %s into your family through adoption." % str(child.get("first_name", "")))
			_append_birth_chronicle(state, child, true)
	return updates

static func spouse_of_player(state: Dictionary) -> Dictionary:
	var player_id := str(state.get("player_id", ""))
	for rel in state.get("relationships", {}).values():
		if "spouse" not in rel.get("roles", []): continue
		var a := str(rel.get("character_a", "")); var b := str(rel.get("character_b", ""))
		var other_id := b if a == player_id else (a if b == player_id else "")
		if other_id.is_empty(): continue
		var other: Dictionary = state.get("characters", {}).get(other_id, {})
		if not other.is_empty() and bool(other.get("alive", true)):
			return other
	return {}

static func children_of_player(state: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var player_id := str(state.get("player_id", ""))
	for link in state.get("family_links", {}).values():
		if str(link.get("parent_id", "")) == player_id and str(link.get("type", "")) in ["biological_parent", "adoptive_parent"]:
			out.append(str(link.get("child_id", "")))
	return out

static func _has_active_family_plan(state: Dictionary) -> bool:
	for r in state.get("pregnancies", []):
		if str(r.get("status", "")) == "active": return true
	for r in state.get("adoption_plans", []):
		if str(r.get("status", "")) == "active": return true
	return false

static func _create_player_child(state: Dictionary, parent_a_id: String, parent_b_id: String, adopted: bool) -> Dictionary:
	var a: Dictionary = state.get("characters", {}).get(parent_a_id, {})
	var b: Dictionary = state.get("characters", {}).get(parent_b_id, {})
	if a.is_empty() or b.is_empty(): return {}
	var player := _player(state)
	var family_id := str(player.get("family_id", ""))
	var family: Dictionary = state.get("families", {}).get(family_id, {})
	if family.is_empty(): return {}
	var id_number := int(state.get("next_character_id", 1))
	var gender := _random_gender()
	var child := CharacterGenerator.generate_child_from_parents("", gender, family, int(state.get("calendar", {}).get("year", 0)), 0, id_number, a, b, adopted)
	state["next_character_id"] = id_number + 1
	child["household_id"] = str(player.get("household_id", ""))
	state["characters"][child["id"]] = child
	if child["id"] not in family.get("member_ids", []): family["member_ids"].append(child["id"])
	if state.get("households", {}).has(str(child["household_id"])) and child["id"] not in state["households"][child["household_id"]].get("member_ids", []):
		state["households"][child["household_id"]]["member_ids"].append(child["id"])
	for parent in [a, b]:
		var number := int(state.get("next_family_link_id", 1)); state["next_family_link_id"] = number + 1
		var link_id := "family_link_%06d" % number
		state["family_links"][link_id] = {"id": link_id, "type": "adoptive_parent" if adopted else "biological_parent", "parent_id": str(parent["id"]), "child_id": str(child["id"])}
		var rel := RelationshipUtils.ensure_relationship(state, str(parent["id"]), str(child["id"]), ["family"])
		rel["familiarity"] = 100; rel["affection"] = 45; rel["trust"] = 30; rel["comfort"] = 35
	return child

static func _merge_households(state: Dictionary, a: Dictionary, b: Dictionary) -> void:
	var new_id := "household_%05d" % int(state.get("next_household_id", 2))
	state["next_household_id"] = int(state.get("next_household_id", 2)) + 1
	_remove_member(state, str(a.get("household_id", "")), str(a["id"]))
	_remove_member(state, str(b.get("household_id", "")), str(b["id"]))
	a["household_id"] = new_id; b["household_id"] = new_id
	state["households"][new_id] = {
		"id": new_id,
		"member_ids": [a["id"], b["id"]],
		"family_ids": _unique([str(a.get("family_id", "")), str(b.get("family_id", ""))]),
		"location_id": str(a.get("location_id", "elscar")),
		"residence_type": "family_home",
		"shared_wealth": int(state.get("money", 0)),
		"status": "active"
	}

static func _remove_member(state: Dictionary, household_id: String, char_id: String) -> void:
	if household_id.is_empty() or not state.get("households", {}).has(household_id): return
	var members: Array = state["households"][household_id].get("member_ids", [])
	var idx := members.find(char_id)
	if idx >= 0: members.remove_at(idx)

static func _append_birth_chronicle(state: Dictionary, child: Dictionary, adopted: bool) -> void:
	var player := _player(state)
	state["chronicle"].append({
		"year": int(state.get("calendar", {}).get("year", 0)),
		"age": int(player.get("age", 0)),
		"category": "family",
		"title": "A Child Joined the Family",
		"summary": "%s joined your household%s." % [str(child.get("display_name", "A child")), " through adoption" if adopted else ""]
	})

static func _player(state: Dictionary) -> Dictionary:
	return state.get("characters", {}).get(str(state.get("player_id", "")), {})

static func _random_gender() -> String:
	return "Woman" if RNGService.npc_rng.randi_range(0, 1) == 0 else "Man"

static func _unique(values: Array) -> Array:
	var out: Array = []
	for v in values:
		var s := str(v)
		if not s.is_empty() and s not in out: out.append(s)
	return out