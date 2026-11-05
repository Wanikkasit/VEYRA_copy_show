extends Node

const EVENT_DIR := "res://content/events"
const ELEMENTS := ["earth", "water", "wind", "fire", "lightning", "wood"]
const CONDITION_TYPES := [
	"age_gte", "age_lte", "has_trait", "skill_gte", "talent_gte",
	"has_affinity", "has_any_affinity", "has_flag", "not_flag", "location_is",
	"career_is", "career_rank_gte", "training_rank_gte", "primary_element_is",
	"martial_discipline_is", "owned_business_type", "business_rank_gte",
	"public_role_is", "has_public_role", "political_service_years_gte", "public_authority_gte",
	"underworld_contact_gte", "mysteries_solved_gte", "expeditions_gte", "site_visits_gte",
	"artifact_count_gte", "education_focus_is", "education_progress_gte",
	"health_gte", "health_lte", "has_health_condition", "has_any_health_condition",
	"money_gte", "money_lte", "household_debt_gte", "social_rank_is", "lifestyle_is",
	"career_performance_gte", "career_performance_lte", "business_quality_gte",
	"business_reputation_gte", "underworld_heat_gte", "underworld_heat_lte",
	"training_progress_gte", "training_tradition_is", "element_mastery_gte",
	"site_progress_gte", "site_successes_gte", "mystery_clues_gte", "mystery_solved",
	"owns_artifact", "world_tension_gte", "world_tension_lte", "location_metric_gte",
	"location_metric_lte", "faction_metric_gte", "faction_metric_lte", "active_situation_is",
	"years_since_inheritance_gte", "years_since_inheritance_lte", "family_reputation_gte",
	"family_reputation_lte", "inherited_faction_reputation_gte", "inherited_faction_reputation_lte",
	"creature_sightings_gte", "creature_knowledge_gte", "creature_population_gte",
	"creature_population_lte", "creature_injuries_gte",
	"creature_victories_gte", "creature_spared_gte",
	"conflict_active", "conflict_phase_is", "conflict_metric_gte", "conflict_metric_lte",
	"conflict_ended", "player_conflict_service_gte",
	"travel_journeys_gte", "travel_relocations_gte", "travel_complications_gte",
	"travel_last_destination_is", "household_home_is", "away_from_household_home",
	"season_is", "local_weather_is", "weather_hazard_gte", "seasonal_metric_gte",
	"seasonal_metric_lte", "festival_is",
	"owns_item", "equipped_item", "equipment_bonus_gte", "possession_count_gte",
	"legal_standing_gte", "legal_standing_lte", "legal_fines_gte", "legal_convictions_gte",
	"legal_case_open", "legal_detained", "legal_probation", "legal_not_detained",
	"story_thread_active", "story_thread_inactive", "story_thread_stage_gte", "story_thread_stage_is", "story_thread_outcome_is",
	"dynasty_generation_gte", "legacy_tag_has", "legacy_echo_count_gte", "legacy_obligation_active",
	"has_spouse", "child_count_gte", "relationship_gte",
	"house_standing_gte", "house_standing_lte", "house_prestige_gte", "house_prestige_lte",
	"house_notoriety_gte", "house_notoriety_lte", "house_legacy_tag_has",
	"property_count_gte", "owns_property_type", "property_condition_gte", "property_condition_lte",
	"property_heritage_gte", "property_inheritance_count_gte", "property_upgrade_has",
	"primary_residence_type_is",
	"culture_practice_is", "culture_commitment_gte", "culture_commitment_lte",
	"culture_trust_gte", "culture_trust_lte", "culture_custom_has", "culture_stance_is",
	"institution_member_is", "institution_any_active", "institution_any_standing_gte", "institution_rank_gte", "institution_standing_gte", "institution_standing_lte",
	"crafting_skill_gte", "crafting_material_gte", "crafting_gathers_gte", "crafting_crafts_gte",
	"life_goal_active", "life_goal_progress_gte", "life_goal_resolve_gte", "life_goal_resolve_lte",
	"market_price_gte", "market_price_lte", "trade_route_condition_gte", "trade_route_condition_lte",
	"mentorship_active", "mentorship_lessons_gte", "mentorship_trust_gte", "mentorship_independence_gte",
	"extended_family_available", "kin_reliability_gte", "kin_rivalry_gte", "kin_expectation_gte",
	"rival_count_gte", "failure_count_gte"
]
const EFFECT_TYPES := [
	"stat_add", "skill_add", "money_add", "health_add", "personality_add",
	"add_trait", "set_flag", "discover_talent", "discover_best_talent",
	"discover_affinities", "relationship_add", "add_memory", "add_family_ward",
	"add_chronicle", "schedule_event", "change_location", "change_character_location",
	"career_performance_add", "faction_reputation_add", "underworld_heat_add",
	"business_reputation_add", "business_quality_add", "world_tension_add",
	"location_metric_add", "training_progress_add", "spouse_relationship_add",
	"children_relationship_add", "legacy_obligation_resolve", "household_debt_add",
	"underworld_notoriety_add", "element_mastery_add", "site_progress_add",
	"mystery_clues_add", "faction_metric_add", "family_reputation_add",
	"creature_knowledge_add", "creature_population_add", "creature_aggression_add",
	"conflict_metric_add", "conflict_service_add", "legal_standing_add",
	"story_thread_start", "story_thread_advance", "story_thread_resolve", "story_thread_fail",
	"house_prestige_add", "house_notoriety_add", "house_legacy_tag_add",
	"property_condition_add", "property_heritage_add",
	"culture_commitment_add", "culture_trust_add", "culture_custom_add", "culture_stance_set",
	"institution_standing_add", "institution_active_standing_add", "institution_service_add", "crafting_material_add",
	"life_goal_resolve_add",
	"market_price_index_add", "market_demand_add", "trade_route_condition_add", "trade_route_volume_add",
	"parenting_security_add", "parenting_guidance_add", "parenting_autonomy_add", "parenting_pressure_add",
	"mentorship_trust_add", "mentorship_discipline_add", "mentorship_independence_add",
	"kin_reliability_add", "kin_shared_history_add", "kin_expectation_add", "kin_rivalry_add",
	"rivalry_grudge_add", "rivalry_conflict_add", "rivalry_respect_add"
]

var events: Dictionary = {}
var validation_errors: Array[String] = []
var validation_warnings: Array[String] = []

func _ready() -> void:
	load_all()

func load_all() -> void:
	events.clear()
	validation_errors.clear()
	validation_warnings.clear()

	var dir := DirAccess.open(EVENT_DIR)
	if dir == null:
		push_error("VEYRA: Event directory could not be opened.")
		return

	for filename in dir.get_files():
		if filename.ends_with(".json"):
			_load_file("%s/%s" % [EVENT_DIR, filename])

	_validate_references()
	if validation_errors.size() > 0:
		for err in validation_errors:
			push_error(err)
	for warning in validation_warnings:
		push_warning(warning)

	print("VEYRA: Loaded %d events." % events.size())

func get_event(event_id: String) -> Dictionary:
	return events.get(event_id, {})

func all_events() -> Array:
	return events.values()

func _load_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		validation_errors.append("Cannot open event file: %s" % path)
		return
	var raw := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(raw) != OK:
		validation_errors.append("Invalid JSON in %s" % path)
		return
	if typeof(json.data) != TYPE_ARRAY:
		validation_errors.append("Event file must contain an array: %s" % path)
		return
	for item in json.data:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = item
		if _validate(event, path):
			events[str(event["id"])] = event

func _validate(event: Dictionary, path: String) -> bool:
	var id := str(event.get("id", ""))
	if id.is_empty():
		validation_errors.append("%s contains event with no id." % path)
		return false
	if events.has(id):
		validation_errors.append("Duplicate event id: %s" % id)
		return false

	for condition in event.get("conditions", []):
		_validate_condition(id, condition)

	var choices: Array = event.get("choices", [])
	if choices.is_empty():
		validation_errors.append("%s has no choices." % id)
		return false
	if choices.size() > 5:
		validation_errors.append("%s has more than 5 choices." % id)
		return false
	if choices.size() > 3:
		validation_warnings.append("%s has %d choices; verify all are meaningful." % [id, choices.size()])

	var unconditional := 0
	for choice in choices:
		var conditions: Array = choice.get("conditions", [])
		if conditions.is_empty():
			unconditional += 1
		if conditions.size() > 2:
			validation_warnings.append("%s choice %s has more than 2 conditions." % [id, str(choice.get("id", "?"))])
		for condition in conditions:
			_validate_condition(id, condition)
		for effect in choice.get("effects", []):
			_validate_effect(id, effect)

	if unconditional == 0:
		validation_errors.append("%s has no unconditional choice." % id)
		return false
	return true

func _validate_condition(event_id: String, condition: Dictionary) -> void:
	var type := str(condition.get("type", ""))
	if type not in CONDITION_TYPES:
		validation_errors.append("%s uses unknown condition type %s." % [event_id, type])
	if type == "has_affinity" and str(condition.get("key", "")) not in ELEMENTS:
		validation_errors.append("%s references non-VEYRA element %s." % [event_id, str(condition.get("key", ""))])

func _validate_effect(event_id: String, effect: Dictionary) -> void:
	var type := str(effect.get("type", ""))
	if type not in EFFECT_TYPES:
		validation_errors.append("%s uses unknown effect type %s." % [event_id, type])

func _validate_references() -> void:
	for event in events.values():
		for choice in event.get("choices", []):
			for effect in choice.get("effects", []):
				if str(effect.get("type", "")) == "schedule_event":
					var target := str(effect.get("event_id", ""))
					if target.is_empty() or not events.has(target):
						validation_errors.append("%s schedules missing event %s." % [str(event.get("id", "")), target])