class_name PortraitCatalogSystem
extends RefCounted

const STANDARD_CATALOG_PATH := "res://ui/portraits/round16/player/catalog.json"
const IMPORTANT_CATALOG_PATH := "res://ui/portraits/round16/important/catalog.json"
const STANDARD_ROOT := "res://ui/portraits/round16/player/"
const IMPORTANT_ROOT := "res://ui/portraits/round16/important/"
const LAYER_ORDER := ["hair_back", "base", "outfit", "eyes", "brows", "mouth", "hair_front"]
const SKIN_TONES := ["light", "white", "medium", "deep"]
const STANDARD_FIELDS := ["identity", "skin_tone", "hairstyle_id", "eyes_id", "brows_id", "mouth_id", "outfit_id"]

static var _standard_catalog: Dictionary = {}
static var _important_catalog: Dictionary = {}
static var _asset_cache: Dictionary = {}

static func identity_for_gender(gender: String) -> String:
	return "man" if gender.to_lower() == "man" else "woman"

static func standard_catalog() -> Dictionary:
	if _standard_catalog.is_empty():
		_standard_catalog = _load_catalog(STANDARD_CATALOG_PATH)
	return _standard_catalog

static func important_catalog() -> Dictionary:
	if _important_catalog.is_empty():
		_important_catalog = _load_catalog(IMPORTANT_CATALOG_PATH)
	return _important_catalog

static func _load_catalog(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

static func standard_hairstyles(identity: String) -> Array[Dictionary]:
	return _hairstyles_for(standard_catalog(), identity)

static func important_hairstyles(identity: String) -> Array[Dictionary]:
	return _hairstyles_for(important_catalog(), identity)

static func _hairstyles_for(catalog: Dictionary, identity: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for variant in catalog.get("hairstyles", []):
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var style: Dictionary = variant
		if str(style.get("identity", "")) == identity:
			out.append(style)
	return out

static func standard_assets(identity: String, category: String) -> Array[Dictionary]:
	return _assets_for(standard_catalog(), identity, category)

static func important_assets(identity: String, category: String) -> Array[Dictionary]:
	return _assets_for(important_catalog(), identity, category)

static func _assets_for(catalog: Dictionary, identity: String, category: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for variant in catalog.get("assets", []):
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var asset: Dictionary = variant
		if str(asset.get("identity", "")) == identity and str(asset.get("category", "")) == category:
			out.append(asset)
	return out

static func standard_option_ids(identity: String, category: String) -> Array[String]:
	var out: Array[String] = []
	for asset in standard_assets(identity, category):
		out.append(str(asset.get("id", "")))
	return out

static func standard_hairstyle_ids(identity: String) -> Array[String]:
	var out: Array[String] = []
	for style in standard_hairstyles(identity):
		out.append(str(style.get("id", "")))
	return out

static func standard_hairstyle_labels(identity: String) -> Array[String]:
	var out: Array[String] = []
	for style in standard_hairstyles(identity):
		var label := str(style.get("label_th", style.get("id", "Hairstyle")))
		out.append(label)
	return out

static func normalize_standard(source: Dictionary, identity: String) -> Dictionary:
	var styles := standard_hairstyles(identity)
	var hairstyle_id := str(source.get("hairstyle_id", ""))
	if not _style_exists(styles, hairstyle_id):
		var legacy_hair := int(source.get("hair_style", source.get("hair", source.get("bangs", source.get("back_hair", 0)))))
		hairstyle_id = str(styles[posmod(legacy_hair, maxi(1, styles.size()))].get("id", "")) if not styles.is_empty() else ""
	var skin_tone := str(source.get("skin_tone", ""))
	if skin_tone not in SKIN_TONES:
		skin_tone = SKIN_TONES[posmod(int(source.get("skin", 0)), SKIN_TONES.size())]
	var eyes_ids := standard_option_ids(identity, "eyes")
	var brows_ids := standard_option_ids(identity, "brows")
	var mouth_ids := standard_option_ids(identity, "mouth")
	var outfit_ids := standard_option_ids(identity, "outfit")
	var result := {
		"identity": identity,
		"skin_tone": skin_tone,
		"hairstyle_id": hairstyle_id,
		"eyes_id": _normalized_id(str(source.get("eyes_id", "")), eyes_ids, int(source.get("eyes", 0))),
		"brows_id": _normalized_id(str(source.get("brows_id", "")), brows_ids, int(source.get("brows", 0))),
		"mouth_id": _normalized_id(str(source.get("mouth_id", "")), mouth_ids, int(source.get("mouth", 0))),
		"outfit_id": _normalized_id(str(source.get("outfit_id", "")), outfit_ids, int(source.get("outfit_style", source.get("clothes", 0)))),
		"portrait_catalog_version": str(standard_catalog().get("version", "16.0"))
	}
	# Numeric aliases exist only for old gameplay code/save migration. hairstyle_id is authoritative.
	result["skin"] = SKIN_TONES.find(skin_tone)
	result["hair_style"] = _style_index(styles, hairstyle_id)
	result["hair"] = result["hair_style"]
	result["bangs"] = result["hair_style"]
	result["back_hair"] = result["hair_style"]
	result["eyes"] = eyes_ids.find(result["eyes_id"])
	result["brows"] = brows_ids.find(result["brows_id"])
	result["mouth"] = mouth_ids.find(result["mouth_id"])
	result["outfit_style"] = outfit_ids.find(result["outfit_id"])
	result["clothes"] = result["outfit_style"]
	result["hair_color"] = 0
	result["eye_color"] = 0
	result["ornament"] = -1
	result["accessory"] = -1
	return result

static func random_standard(identity: String, rng: RandomNumberGenerator) -> Dictionary:
	var styles := standard_hairstyle_ids(identity)
	var eyes := standard_option_ids(identity, "eyes")
	var brows := standard_option_ids(identity, "brows")
	var mouths := standard_option_ids(identity, "mouth")
	var outfits := standard_option_ids(identity, "outfit")
	return normalize_standard({
		"skin_tone": SKIN_TONES[rng.randi_range(0, SKIN_TONES.size() - 1)],
		"hairstyle_id": styles[rng.randi_range(0, styles.size() - 1)],
		"eyes_id": eyes[rng.randi_range(0, eyes.size() - 1)],
		"brows_id": brows[rng.randi_range(0, brows.size() - 1)],
		"mouth_id": mouths[rng.randi_range(0, mouths.size() - 1)],
		"outfit_id": outfits[rng.randi_range(0, outfits.size() - 1)]
	}, identity)

static func inherit_standard(identity: String, rng: RandomNumberGenerator, parent_a: Dictionary, parent_b: Dictionary) -> Dictionary:
	var fresh := random_standard(identity, rng)
	var result := fresh.duplicate(true)
	for field in ["skin_tone", "eyes_id", "brows_id", "mouth_id", "hairstyle_id"]:
		var roll := rng.randf()
		var source: Dictionary = parent_a if roll < 0.45 else parent_b
		if roll < 0.90:
			var inherited: Variant = _map_parent_field(identity, field, source)
			if inherited != null:
				result[field] = inherited
	return normalize_standard(result, identity)

static func _map_parent_field(identity: String, field: String, parent_character: Dictionary) -> Variant:
	var appearance: Dictionary = parent_character.get("appearance", {})
	var parent_identity := str(appearance.get("identity", identity_for_gender(str(parent_character.get("gender", "Woman")))))
	var parent := normalize_standard(appearance, parent_identity)
	if field == "skin_tone":
		return parent.get(field)
	if field == "hairstyle_id":
		var from := standard_hairstyle_ids(parent_identity)
		var to := standard_hairstyle_ids(identity)
		var idx := from.find(str(parent.get(field, "")))
		return to[posmod(idx, to.size())] if idx >= 0 and not to.is_empty() else null
	var category: String = str({"eyes_id":"eyes", "brows_id":"brows", "mouth_id":"mouth"}.get(field, ""))
	var from_ids := standard_option_ids(parent_identity, category)
	var to_ids := standard_option_ids(identity, category)
	var idx := from_ids.find(str(parent.get(field, "")))
	return to_ids[posmod(idx, to_ids.size())] if idx >= 0 and not to_ids.is_empty() else null

static func set_standard_outfit_index(appearance: Dictionary, identity: String, index: int) -> Dictionary:
	var normalized := normalize_standard(appearance, identity)
	var ids := standard_option_ids(identity, "outfit")
	if not ids.is_empty():
		normalized["outfit_id"] = ids[posmod(index, ids.size())]
	return normalize_standard(normalized, identity)

static func resolve_standard_layers(source: Dictionary, identity: String) -> Array[Dictionary]:
	var state := normalize_standard(source, identity)
	var catalog := standard_catalog()
	var style := _style_by_id(catalog, str(state.get("hairstyle_id", "")), identity)
	if style.is_empty():
		return []
	var ids := {
		"hair_back": str(style.get("back", "")),
		"base": "%s-base-%s" % [identity, str(state.get("skin_tone", "light"))],
		"outfit": str(state.get("outfit_id", "")),
		"eyes": str(state.get("eyes_id", "")),
		"brows": str(state.get("brows_id", "")),
		"mouth": str(state.get("mouth_id", "")),
		"hair_front": str(style.get("front", ""))
	}
	return _resolve_layer_assets(catalog, identity, ids, false, {})

static func resolve_important_layers(state: Dictionary, identity: String, context: Dictionary) -> Array[Dictionary]:
	var catalog := important_catalog()
	if str(catalog.get("access", "")) != "important_npc" or bool(catalog.get("player_allowed", true)) or bool(catalog.get("ordinary_npc_allowed", true)):
		return []
	var style := _style_by_id(catalog, str(state.get("hairstyle_id", "")), identity)
	if style.is_empty() or not important_entry_eligible(style, context):
		return []
	var ids := {
		"hair_back": str(style.get("back", "")),
		"base": "npc-%s-base-%s" % [identity, str(state.get("skin_tone", "light"))],
		"outfit": str(state.get("outfit_id", "")),
		"eyes": str(state.get("eyes_id", "")),
		"brows": str(state.get("brows_id", "")),
		"mouth": str(state.get("mouth_id", "")),
		"hair_front": str(style.get("front", ""))
	}
	return _resolve_layer_assets(catalog, identity, ids, true, context)

static func _resolve_layer_assets(catalog: Dictionary, identity: String, ids: Dictionary, enforce_eligibility: bool, context: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for category in LAYER_ORDER:
		var asset := _asset_by_id(catalog, str(ids.get(category, "")))
		if asset.is_empty() or str(asset.get("identity", "")) != identity or str(asset.get("category", "")) != category:
			return []
		if enforce_eligibility and not important_entry_eligible(asset, context):
			return []
		out.append(asset)
	return out

static func important_entry_eligible(entry: Dictionary, context: Dictionary) -> bool:
	var age := int(context.get("age", -1))
	if age < int(entry.get("min_age", 18)):
		return false
	if entry.has("max_age") and age > int(entry.get("max_age", 9999)):
		return false
	var required_role := str(entry.get("required_role", ""))
	if not required_role.is_empty() and required_role != str(context.get("current_role", "")):
		return false
	var allowed: Variant = entry.get("allowed_personalities", null)
	if typeof(allowed) == TYPE_ARRAY and not allowed.is_empty() and str(context.get("personality", "")) not in allowed:
		return false
	return true

static func important_role_exists(role_id: String) -> bool:
	for variant in important_catalog().get("roles", []):
		if typeof(variant) == TYPE_DICTIONARY and str(variant.get("id", "")) == role_id:
			return true
	return false

static func load_asset_image(asset: Dictionary, important: bool = false) -> Image:
	var root := IMPORTANT_ROOT if important else STANDARD_ROOT
	var key := ("important:" if important else "standard:") + str(asset.get("id", ""))
	if _asset_cache.has(key):
		return _asset_cache[key]
	var path := root + str(asset.get("path", ""))

	# Source/test builds keep the raw PNG, while exported Android builds may
	# remap it to an imported Texture2D. Prefer the raw image when present so
	# headless source tests stay quiet, then fall back to ResourceLoader for APK.
	if FileAccess.file_exists(path):
		var raw := Image.new()
		if raw.load(path) == OK and raw.get_size() == Vector2i(160, 176):
			_asset_cache[key] = raw
			return raw

	var resource: Resource = ResourceLoader.load(path)
	if resource == null or not (resource is Texture2D):
		return null
	var image: Image = (resource as Texture2D).get_image()
	if image == null or image.get_size() != Vector2i(160, 176):
		return null
	_asset_cache[key] = image
	return image

static func _normalized_id(value: String, ids: Array[String], fallback_index: int) -> String:
	if value in ids:
		return value
	return ids[posmod(fallback_index, ids.size())] if not ids.is_empty() else ""

static func _style_exists(styles: Array[Dictionary], style_id: String) -> bool:
	for style in styles:
		if str(style.get("id", "")) == style_id:
			return true
	return false

static func _style_index(styles: Array[Dictionary], style_id: String) -> int:
	for i in range(styles.size()):
		if str(styles[i].get("id", "")) == style_id:
			return i
	return 0

static func _style_by_id(catalog: Dictionary, style_id: String, identity: String) -> Dictionary:
	for variant in catalog.get("hairstyles", []):
		if typeof(variant) != TYPE_DICTIONARY:
			continue
		var style: Dictionary = variant
		if str(style.get("id", "")) == style_id and str(style.get("identity", "")) == identity:
			return style
	return {}

static func _asset_by_id(catalog: Dictionary, asset_id: String) -> Dictionary:
	for variant in catalog.get("assets", []):
		if typeof(variant) == TYPE_DICTIONARY and str(variant.get("id", "")) == asset_id:
			return variant
	return {}