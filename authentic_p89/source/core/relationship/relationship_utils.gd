class_name RelationshipUtils
extends RefCounted

static func relationship_id(a: String, b: String) -> String:
	var pair := [a, b]
	pair.sort()
	return "rel_%s_%s" % [pair[0], pair[1]]

static func ensure_relationship(state: Dictionary, a: String, b: String, initial_roles: Array = []) -> Dictionary:
	if a.is_empty() or b.is_empty() or a == b:
		return {}
	if not state.has("relationships"):
		state["relationships"] = {}
	var id := relationship_id(a, b)
	if not state["relationships"].has(id):
		state["relationships"][id] = {
			"id": id,
			"character_a": a,
			"character_b": b,
			"familiarity": 0,
			"affection": 0,
			"trust": 0,
			"respect": 0,
			"attraction": 0,
			"comfort": 0,
			"conflict": 0,
			"roles": [],
			"memories": [],
			"flags": {},
			"started_year": int(state.get("calendar", {}).get("year", 0))
		}
	var rel: Dictionary = state["relationships"][id]
	for role in initial_roles:
		var role_name := str(role)
		if not role_name.is_empty() and role_name not in rel["roles"]:
			rel["roles"].append(role_name)
	return rel

static func get_relationship(state: Dictionary, a: String, b: String) -> Dictionary:
	return state.get("relationships", {}).get(relationship_id(a, b), {})

static func add_role(rel: Dictionary, role: String) -> void:
	if role.is_empty():
		return
	if role not in rel.get("roles", []):
		rel["roles"].append(role)

static func remove_role(rel: Dictionary, role: String) -> void:
	var roles: Array = rel.get("roles", [])
	var idx := roles.find(role)
	if idx >= 0:
		roles.remove_at(idx)

static func has_role(rel: Dictionary, role: String) -> bool:
	return role in rel.get("roles", [])