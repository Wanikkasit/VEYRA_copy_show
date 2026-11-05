class_name EventDirector
extends RefCounted

const ConditionEvaluatorClass = preload("res://core/events/condition_evaluator.gd")
const EffectResolverClass = preload("res://core/events/effect_resolver.gd")
const StoryThreadSystemClass = preload("res://core/narrative/story_thread_system.gd")

static func select_event(state: Dictionary, activity: String, force: bool = false) -> Dictionary:
	if activity == "test":
		for raw in EventDB.all_events():
			var debug_event: Dictionary = raw
			if bool(debug_event.get("debug_only", false)):
				return _make_instance(debug_event, state, {})
	var scheduled_instance := _take_due_scheduled_event(state)
	if not scheduled_instance.is_empty():
		return scheduled_instance

	var path_instance := _take_due_path_narrative(state, activity)
	if not path_instance.is_empty():
		return path_instance

	var eligible: Array = []
	var total_weight := 0
	for raw in EventDB.all_events():
		var event: Dictionary = raw
		if bool(event.get("scheduled_only", false)) or bool(event.get("debug_only", false)) or bool(event.get("year_fallback", false)):
			continue
		if not _p87_age_appropriate(event, state):
			continue
		if not ConditionEvaluatorClass.all_pass(event.get("conditions", []), state):
			continue
		if not _history_allows(event, state):
			continue
		if not _participants_resolvable(event, state, {}):
			continue

		var weight := int(event.get("weight", 10))
		var activity_tags: Array = event.get("activity_tags", [])
		if activity in activity_tags:
			weight *= 2
		weight = _p88_tone_adjusted_weight(event, state, weight)
		if weight <= 0:
			continue
		eligible.append({"event": event, "weight": weight})
		total_weight += weight

	if eligible.is_empty():
		return {}

	# Quiet turns remain normal gameplay. Tester tools may bypass only this chance gate.
	if not force and RNGService.event_rng.randf() > 0.72:
		return {}

	var roll := RNGService.event_rng.randi_range(1, total_weight)
	var cursor := 0
	for entry in eligible:
		cursor += int(entry["weight"])
		if roll <= cursor:
			return _make_instance(entry["event"], state, {})

	return {}

static func make_specific_event(event_id: String, state: Dictionary) -> Dictionary:
	var event: Dictionary = EventDB.get_event(event_id)
	if event.is_empty():
		return {}
	return _make_instance(event, state, _story_thread_context(event, state))

static func _story_thread_context(event: Dictionary, state: Dictionary) -> Dictionary:
	for condition_variant in event.get("conditions", []):
		if typeof(condition_variant) != TYPE_DICTIONARY:
			continue
		var condition: Dictionary = condition_variant
		if str(condition.get("type", "")) not in ["story_thread_active", "story_thread_stage_gte", "story_thread_stage_is"]:
			continue
		var thread_key := str(condition.get("key", ""))
		if thread_key.is_empty():
			continue
		return StoryThreadSystemClass.context_for(state, thread_key)
	return {}

static func available_choices(instance: Dictionary, state: Dictionary) -> Array:
	var event := EventDB.get_event(str(instance.get("event_id", "")))
	if event.is_empty():
		return [{"id": "_fallback", "text": "Continue", "conditions": [], "effects": []}]

	var output: Array = []
	var context: Dictionary = instance.get("context", {})
	for raw_choice in event.get("choices", []):
		var choice: Dictionary = raw_choice
		if ConditionEvaluatorClass.all_pass(choice.get("conditions", []), state, context):
			output.append(choice)

	if output.is_empty():
		return [{"id": "_fallback", "text": "Continue", "conditions": [], "effects": []}]
	return output

static func resolve_selected(instance: Dictionary, state: Dictionary) -> void:
	var event := EventDB.get_event(str(instance.get("event_id", "")))
	if event.is_empty():
		return

	var selected_id := str(instance.get("selected_choice_id", ""))
	if selected_id == "_fallback":
		_mark_history(event, state)
		return

	var selected: Dictionary = {}
	for raw_choice in event.get("choices", []):
		if str(raw_choice.get("id", "")) == selected_id:
			selected = raw_choice
			break

	if selected.is_empty():
		return

	EffectResolverClass.apply_all(selected.get("effects", []), state, instance.get("context", {}))
	_mark_history(event, state)

	var player := _player(state)
	state["chronicle"].append({
		"year": int(state.get("calendar", {}).get("year", 0)),
		"age": int(player.get("age", 0)),
		"category": str(event.get("category", "life")),
		"title": str(event.get("title", "Life Event")),
		"summary": str(selected.get("result_text", selected.get("text", "")))
	})


static func _p88_event_tone(event: Dictionary) -> String:
	var explicit := str(event.get("tone", ""))
	if explicit in ["light", "neutral", "dark", "deep_dark", "reflective"]:
		return explicit
	var domain := str(event.get("content_domain", ""))
	if domain in [
		"dangerous_creature", "regional_conflict", "border_conflict", "banditry",
		"arcane_instability", "justice_legal", "enterprise_crisis"
	]:
		return "dark"
	if domain in [
		"ordinary_life", "seasonal_local", "npc_liveliness", "parenting",
		"culture_community", "failure_recovery"
	]:
		return "light"
	return "neutral"

static func _p88_recent_tones(state: Dictionary) -> Array:
	var player: Dictionary = _player(state)
	if player.is_empty():
		return []
	if typeof(player.get("flags", null)) != TYPE_DICTIONARY:
		return []
	var raw: Variant = player["flags"].get("_p88_tone_history", [])
	return raw if typeof(raw) == TYPE_ARRAY else []

static func _p88_tone_adjusted_weight(event: Dictionary, state: Dictionary, base_weight: int) -> int:
	if base_weight <= 0:
		return 0
	var tone := _p88_event_tone(event)
	var history: Array = _p88_recent_tones(state)
	var dark_streak := 0
	for i in range(history.size() - 1, -1, -1):
		if str(history[i]) in ["dark", "deep_dark"]:
			dark_streak += 1
		else:
			break
	var adjusted := float(base_weight)
	if tone in ["dark", "deep_dark"]:
		if dark_streak >= 2:
			adjusted *= 0.15
		elif dark_streak == 1:
			adjusted *= 0.45
		if tone == "deep_dark" and dark_streak >= 1:
			adjusted *= 0.60
	elif tone == "light" and dark_streak >= 2:
		adjusted *= 2.5
	elif tone == "reflective" and dark_streak >= 1:
		adjusted *= 1.6
	return maxi(1, int(round(adjusted)))

static func _p88_record_tone(event: Dictionary, state: Dictionary) -> void:
	var player: Dictionary = _player(state)
	if player.is_empty():
		return
	if typeof(player.get("flags", null)) != TYPE_DICTIONARY:
		player["flags"] = {}
	var history: Array = player["flags"].get("_p88_tone_history", [])
	if typeof(history) != TYPE_ARRAY:
		history = []
	history.append(_p88_event_tone(event))
	while history.size() > 4:
		history.pop_front()
	player["flags"]["_p88_tone_history"] = history

static func _p87_age_appropriate(event: Dictionary, state: Dictionary) -> bool:
	var player: Dictionary = _player(state)
	if player.is_empty():
		return true
	var age := int(player.get("age", 0))
	if age >= 18:
		return true
	if bool(event.get("youth_safe", false)):
		return true
	var has_explicit_age_bound := false
	for raw_condition in event.get("conditions", []):
		if typeof(raw_condition) != TYPE_DICTIONARY:
			continue
		var condition: Dictionary = raw_condition
		if str(condition.get("type", "")) in ["age_gte", "age_lte"]:
			has_explicit_age_bound = true
			break
	return has_explicit_age_bound

static func event_pool_stats(state: Dictionary, activity: String = "") -> Dictionary:
	var stats := {
		"generic_total": 0,
		"eligible": 0,
		"activity_eligible": 0,
		"repeatable_total": 0,
		"repeatable_eligible": 0,
		"blocked_conditions": 0,
		"blocked_history": 0,
		"blocked_participants": 0
	}
	for raw in EventDB.all_events():
		var event: Dictionary = raw
		if bool(event.get("scheduled_only", false)) or bool(event.get("debug_only", false)) or bool(event.get("year_fallback", false)):
			continue
		stats["generic_total"] = int(stats["generic_total"]) + 1
		if bool(event.get("repeatable", false)):
			stats["repeatable_total"] = int(stats["repeatable_total"]) + 1
		if not _p87_age_appropriate(event, state):
			continue
		if not ConditionEvaluatorClass.all_pass(event.get("conditions", []), state):
			stats["blocked_conditions"] = int(stats["blocked_conditions"]) + 1
			continue
		if not _history_allows(event, state):
			stats["blocked_history"] = int(stats["blocked_history"]) + 1
			continue
		if not _participants_resolvable(event, state, {}):
			stats["blocked_participants"] = int(stats["blocked_participants"]) + 1
			continue
		stats["eligible"] = int(stats["eligible"]) + 1
		if bool(event.get("repeatable", false)):
			stats["repeatable_eligible"] = int(stats["repeatable_eligible"]) + 1
		if activity.is_empty() or activity in event.get("activity_tags", []):
			stats["activity_eligible"] = int(stats["activity_eligible"]) + 1
	return stats

static func history_allows_event(event_id: String, state: Dictionary) -> bool:
	var event: Dictionary = EventDB.get_event(event_id)
	return not event.is_empty() and _history_allows(event, state)

static func compact_character_history(state: Dictionary, character_id: String) -> int:
	if character_id.is_empty() or typeof(state.get("event_history", null)) != TYPE_DICTIONARY:
		return 0
	var history: Dictionary = state["event_history"]
	var prefix := character_id + ":"
	var removed := 0
	for raw_key in history.keys().duplicate():
		var key := str(raw_key)
		if key.begins_with(prefix):
			history.erase(raw_key)
			removed += 1
	state["event_history"] = history
	return removed

static func _history_allows(event: Dictionary, state: Dictionary) -> bool:
	var id := _history_key(event, state)
	var history_entry = state.get("event_history", {}).get(id, null)
	if history_entry == null:
		return true
	if not bool(event.get("repeatable", false)):
		return false
	var cooldown := int(event.get("cooldown_years", 0))
	if cooldown <= 0:
		return true
	var last_year := 0
	if typeof(history_entry) == TYPE_DICTIONARY:
		last_year = int(history_entry.get("last_year", 0))
	return int(state.get("calendar", {}).get("year", 0)) - last_year >= cooldown

static func _mark_history(event: Dictionary, state: Dictionary) -> void:
	var id := _history_key(event, state)
	var previous = state.get("event_history", {}).get(id, {})
	var count := 0
	if typeof(previous) == TYPE_DICTIONARY:
		count = int(previous.get("count", 0))
	elif previous != null:
		count = 1
	state["event_history"][id] = {
		"count": count + 1,
		"last_year": int(state.get("calendar", {}).get("year", 0))
	}
	_p88_record_tone(event, state)

static func _history_key(event: Dictionary, state: Dictionary) -> String:
	var event_id := str(event.get("id", ""))
	var scope := str(event.get("history_scope", "character"))
	match scope:
		"world":
			return "world:%s" % event_id
		"dynasty":
			return "dynasty:%s" % event_id
		_:
			return "%s:%s" % [str(state.get("player_id", "")), event_id]

static func _make_instance(event: Dictionary, state: Dictionary, supplied_context: Dictionary) -> Dictionary:
	if not ConditionEvaluatorClass.all_pass(event.get("conditions", []), state, supplied_context):
		return {}
	if not _participants_resolvable(event, state, supplied_context):
		return {}

	var context: Dictionary = supplied_context.duplicate(true)
	for role in event.get("participants", []):
		var role_name := str(role)
		if context.has(role_name):
			continue
		var candidates := _participant_candidates(role_name, state)
		if candidates.is_empty():
			return {}
		context[role_name] = candidates[RNGService.event_rng.randi_range(0, candidates.size() - 1)]

	return {
		"event_id": str(event.get("id", "")),
		"status": "presented",
		"selected_choice_id": "",
		"context": context
	}

static func _participants_resolvable(event: Dictionary, state: Dictionary, supplied_context: Dictionary) -> bool:
	var characters: Dictionary = state.get("characters", {})
	for role in event.get("participants", []):
		var role_name := str(role)
		if supplied_context.has(role_name):
			var supplied_id := str(supplied_context[role_name])
			var supplied_char: Dictionary = characters.get(supplied_id, {})
			if supplied_char.is_empty() or not bool(supplied_char.get("alive", true)):
				return false
			continue
		if _participant_candidates(role_name, state).is_empty():
			return false
	return true

static func _participant_candidates(role: String, state: Dictionary) -> Array[String]:
	var player_id := str(state.get("player_id", ""))
	var characters: Dictionary = state.get("characters", {})
	var rels: Dictionary = state.get("relationships", {})
	var player := _player(state)
	var candidates: Array[String] = []

	if role == "parent":
		return _parents_of(state, player_id)
	if role == "sibling":
		return _siblings_of(state, player_id)
	if role == "family_member":
		for id in characters.keys():
			var char_id := str(id)
			if char_id == player_id:
				continue
			var c: Dictionary = characters[char_id]
			if bool(c.get("alive", true)) and str(c.get("family_id", "")) == str(player.get("family_id", "")):
				candidates.append(char_id)
		return candidates

	for id in characters.keys():
		var char_id := str(id)
		if char_id == player_id:
			continue
		var npc: Dictionary = characters[char_id]
		if not bool(npc.get("alive", true)):
			continue

		var rel := _get_relationship(rels, player_id, char_id)
		var roles: Array = rel.get("roles", [])

		match role:
			"partner":
				if "partner" in roles:
					candidates.append(char_id)
			"spouse":
				if "spouse" in roles:
					candidates.append(char_id)
			"former_partner":
				if "former_partner" in roles:
					candidates.append(char_id)
			"former_spouse":
				if "former_spouse" in roles:
					candidates.append(char_id)
			"romantic_interest":
				if abs(int(npc.get("age", 0)) - int(player.get("age", 0))) <= 12 and int(rel.get("familiarity", 0)) >= 15 and RomanceSystem.can_romance(state, char_id):
					candidates.append(char_id)
			"royal_peer":
				if abs(int(npc.get("age", 0)) - int(player.get("age", 0))) <= 5 and str(npc.get("role_hint", "")) == "royal_peer":
					candidates.append(char_id)
			"colleague":
				if int(player.get("age", 0)) >= 18 and str(npc.get("career", "")) == str(player.get("career", "")) and str(npc.get("family_id", "")) != str(player.get("family_id", "")):
					candidates.append(char_id)
			"known_contact":
				if not rel.is_empty() and int(rel.get("familiarity", 0)) >= 5:
					candidates.append(char_id)
			"nearby_contact":
				if str(npc.get("location_id", "")) == str(player.get("location_id", "")):
					candidates.append(char_id)
			"child":
				if _is_child_of(state, char_id, player_id):
					candidates.append(char_id)
			"childhood_friend":
				if abs(int(npc.get("age", 0)) - int(player.get("age", 0))) <= 5 and ("childhood_friend" in roles or "friend" in roles):
					candidates.append(char_id)
			"friend":
				if "friend" in roles:
					candidates.append(char_id)
			"rival":
				if "rival" in roles:
					candidates.append(char_id)
			"mentorship_counterpart":
				for p88_bond_variant in state.get("mentorship_world", {}).get("bonds", {}).values():
					if typeof(p88_bond_variant) != TYPE_DICTIONARY:
						continue
					var p88_bond: Dictionary = p88_bond_variant
					if not bool(p88_bond.get("active", false)):
						continue
					var p88_mentor := str(p88_bond.get("mentor_id", ""))
					var p88_student := str(p88_bond.get("student_id", ""))
					if p88_mentor == player_id and p88_student == char_id:
						candidates.append(char_id)
					elif p88_student == player_id and p88_mentor == char_id:
						candidates.append(char_id)
			"mentor":
				if "mentor_student" in roles and str(rel.get("flags", {}).get("mentor_id", "")) == char_id and str(rel.get("flags", {}).get("student_id", "")) == player_id:
					candidates.append(char_id)
			"student":
				if "mentor_student" in roles and str(rel.get("flags", {}).get("student_id", "")) == char_id and str(rel.get("flags", {}).get("mentor_id", "")) == player_id:
					candidates.append(char_id)
			"prodigy":
				if abs(int(npc.get("age", 0)) - int(player.get("age", 0))) <= 5 and str(npc.get("role_hint", "")) == "prodigy":
					candidates.append(char_id)
			"socially_important_peer":
				if abs(int(npc.get("age", 0)) - int(player.get("age", 0))) <= 5 and str(npc.get("role_hint", "")) == "socially_important":
					candidates.append(char_id)
			"family_ward":
				if "family_ward" in roles:
					candidates.append(char_id)
			"legacy_contact":
				if "family_legacy_contact" in roles:
					candidates.append(char_id)
			"legacy_goodwill_contact":
				if "family_legacy_contact" in roles and str(rel.get("flags", {}).get("legacy_sentiment", "")) == "goodwill":
					candidates.append(char_id)
			"legacy_grudge_contact":
				if "family_legacy_contact" in roles and str(rel.get("flags", {}).get("legacy_sentiment", "")) == "grudge":
					candidates.append(char_id)
			"peer":
				if abs(int(npc.get("age", 0)) - int(player.get("age", 0))) <= 5 and str(npc.get("role_hint", "")) != "parent":
					candidates.append(char_id)
			"stranger":
				if str(npc.get("role_hint", "")) != "parent":
					candidates.append(char_id)
			_:
				if abs(int(npc.get("age", 0)) - int(player.get("age", 0))) <= 5:
					candidates.append(char_id)

	return candidates



static func _take_due_path_narrative(state: Dictionary, activity: String) -> Dictionary:
	var player: Dictionary = _player(state)
	if player.is_empty():
		return {}
	if typeof(player.get("flags", null)) != TYPE_DICTIONARY:
		player["flags"] = {}
	var year := int(state.get("calendar", {}).get("year", 0))
	var path_year := int(player["flags"].get("_path_narrative_year", -999999))
	if path_year != year:
		player["flags"]["_path_narrative_year"] = year
		player["flags"]["_path_narrative_count"] = 0
		player["flags"]["_path_narrative_paths"] = []
	if int(player["flags"].get("_path_narrative_count", 0)) >= 2:
		return {}
	var used_paths: Array = player["flags"].get("_path_narrative_paths", [])
	var eligible: Array[Dictionary] = []
	for raw in EventDB.all_events():
		var event: Dictionary = raw
		if not bool(event.get("path_narrative", false)):
			continue
		var path_key := "%s:%s" % [str(event.get("path_family", "general")), str(event.get("path_id", event.get("id", "")))]
		if path_key in used_paths:
			continue
		if not _p87_age_appropriate(event, state):
			continue
		if not ConditionEvaluatorClass.all_pass(event.get("conditions", []), state):
			continue
		if not _history_allows(event, state):
			continue
		if not _participants_resolvable(event, state, {}):
			continue
		var tags: Array = event.get("activity_tags", [])
		var tag_match := tags.is_empty() or activity in tags
		var priority := int(event.get("path_priority", 50)) + (20 if tag_match else 0)
		eligible.append({"event": event, "priority": priority})
	if eligible.is_empty():
		return {}
	eligible.sort_custom(func(a, b):
		var pa := int(a.get("priority", 0))
		var pb := int(b.get("priority", 0))
		if pa != pb:
			return pa > pb
		return str(a.get("event", {}).get("id", "")) < str(b.get("event", {}).get("id", ""))
	)
	var chosen_event: Dictionary = eligible[0]["event"]
	var instance := _make_instance(chosen_event, state, {})
	if not instance.is_empty():
		var chosen_key := "%s:%s" % [str(chosen_event.get("path_family", "general")), str(chosen_event.get("path_id", chosen_event.get("id", "")))]
		player["flags"]["_path_narrative_count"] = int(player["flags"].get("_path_narrative_count", 0)) + 1
		if chosen_key not in used_paths:
			used_paths.append(chosen_key)
		player["flags"]["_path_narrative_paths"] = used_paths
		player["flags"]["_path_narrative_last_year"] = year
	return instance

static func _take_due_scheduled_event(state: Dictionary) -> Dictionary:
	var year := int(state.get("calendar", {}).get("year", 0))
	var schedule: Array = state.get("scheduled_events", [])
	var i := 0
	while i < schedule.size():
		var item: Dictionary = schedule[i]
		var owner_player_id := str(item.get("owner_player_id", ""))
		if not owner_player_id.is_empty() and owner_player_id != str(state.get("player_id", "")) and not bool(item.get("inherit_across_generations", false)):
			schedule.remove_at(i)
			continue
		var due_year := int(item.get("due_year", 999999))
		var expire_year := int(item.get("expire_year", due_year + 5))
		if year > expire_year:
			schedule.remove_at(i)
			continue
		if year < due_year:
			i += 1
			continue
		var event := EventDB.get_event(str(item.get("event_id", "")))
		if event.is_empty():
			schedule.remove_at(i)
			continue
		var supplied_context: Dictionary = item.get("context", {})
		var instance := _make_instance(event, state, supplied_context)
		if not instance.is_empty():
			schedule.remove_at(i)
			return instance
		i += 1
	return {}

static func _parents_of(state: Dictionary, child_id: String) -> Array[String]:
	var out: Array[String] = []
	for link in state.get("family_links", {}).values():
		if str(link.get("child_id", "")) == child_id and str(link.get("type", "")) in ["biological_parent", "adoptive_parent"]:
			var parent_id := str(link.get("parent_id", ""))
			var parent: Dictionary = state.get("characters", {}).get(parent_id, {})
			if not parent.is_empty() and bool(parent.get("alive", true)):
				out.append(parent_id)
	return out

static func _siblings_of(state: Dictionary, child_id: String) -> Array[String]:
	var parents := _parents_of_all(state, child_id)
	var out: Array[String] = []
	if parents.is_empty():
		return out
	for other_id in state.get("characters", {}).keys():
		var id := str(other_id)
		if id == child_id:
			continue
		var other: Dictionary = state["characters"][id]
		if not bool(other.get("alive", true)):
			continue
		var other_parents := _parents_of_all(state, id)
		var shared := false
		for parent_id in parents:
			if parent_id in other_parents:
				shared = true
				break
		if shared:
			out.append(id)
	return out

static func _parents_of_all(state: Dictionary, child_id: String) -> Array[String]:
	var out: Array[String] = []
	for link in state.get("family_links", {}).values():
		if str(link.get("child_id", "")) == child_id and str(link.get("type", "")) in ["biological_parent", "adoptive_parent"]:
			out.append(str(link.get("parent_id", "")))
	return out

static func _is_child_of(state: Dictionary, child_id: String, parent_id: String) -> bool:
	for link in state.get("family_links", {}).values():
		if str(link.get("parent_id", "")) == parent_id and str(link.get("child_id", "")) == child_id and str(link.get("type", "")) in ["biological_parent", "adoptive_parent"]:
			return true
	return false

static func _player(state: Dictionary) -> Dictionary:
	var id := str(state.get("player_id", ""))
	return state.get("characters", {}).get(id, {})

static func _get_relationship(rels: Dictionary, a: String, b: String) -> Dictionary:
	return rels.get(RelationshipUtils.relationship_id(a, b), {})
