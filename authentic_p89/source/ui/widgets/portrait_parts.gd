class_name PortraitParts
extends RefCounted

const SOCKET_VERSION := 6
const EXPRESSIONS := ["neutral", "happy", "shy", "sad", "angry"]

# HF12 keeps only the major user-facing categories. Legacy fields are accepted
# so existing saves still load, but colors/ornaments are fixed and not selectable.
const COUNTS := {
	"skin": 6,
	"eyes": 8,
	"brows": 6,
	"mouth": 6,
	"hair_style": 12,
	"outfit_style": 8
}

const SOCKETS := {
	"canvas": Vector2i(64, 80),
	"face_center": Vector2i(32, 36),
	"left_eye": Vector2i(24, 35),
	"right_eye": Vector2i(40, 35),
	"mouth": Vector2i(32, 47),
	"neck_center": Vector2i(32, 56),
	"shoulder_line": 61
}

static func _canonical_key(key: String) -> String:
	match key:
		"hair", "bangs", "back_hair":
			return "hair_style"
		"clothes":
			return "outfit_style"
		_:
			return key

static func count(key: String) -> int:
	return int(COUNTS.get(_canonical_key(key), 1))

static func valid_expression(value: String) -> String:
	return value if value in EXPRESSIONS else "neutral"

static func default_appearance() -> Dictionary:
	return normalize_appearance({
		"skin": 1,
		"eyes": 0,
		"brows": 0,
		"mouth": 0,
		"hair_style": 3,
		"outfit_style": 0
	})

static func normalize_appearance(source: Dictionary) -> Dictionary:
	var raw_hair = source.get("hair_style", source.get("back_hair", source.get("hair", source.get("bangs", 0))))
	var raw_outfit = source.get("outfit_style", source.get("clothes", 0))
	var a := {
		"skin": posmod(int(source.get("skin", 0)), count("skin")),
		"eyes": posmod(int(source.get("eyes", 0)), count("eyes")),
		"brows": posmod(int(source.get("brows", 0)), count("brows")),
		"mouth": posmod(int(source.get("mouth", 0)), count("mouth")),
		"hair_style": posmod(int(raw_hair), count("hair_style")),
		"outfit_style": posmod(int(raw_outfit), count("outfit_style"))
	}
	# Compatibility aliases only. They are not independent customization parts.
	a["hair"] = a["hair_style"]
	a["bangs"] = a["hair_style"]
	a["back_hair"] = a["hair_style"]
	a["clothes"] = a["outfit_style"]
	a["eye_color"] = 0
	a["hair_color"] = 0
	a["ornament"] = -1
	a["accessory"] = -1
	a["portrait_socket_version"] = SOCKET_VERSION
	return a

static func combination_is_valid(source: Dictionary) -> bool:
	var a := normalize_appearance(source)
	if int(a.get("portrait_socket_version", -1)) != SOCKET_VERSION:
		return false
	for key in ["skin", "eyes", "brows", "mouth", "hair_style", "outfit_style"]:
		var value := int(a.get(key, -1))
		if value < 0 or value >= count(key):
			return false
	var hair_style := int(a.get("hair_style", -1))
	return int(a.get("hair", -2)) == hair_style and int(a.get("bangs", -2)) == hair_style and int(a.get("back_hair", -2)) == hair_style

static func critical_combination_count() -> int:
	return 2 * count("skin") * count("eyes") * count("brows") * count("mouth") * count("hair_style") * count("outfit_style")
