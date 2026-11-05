class_name PortraitWidget
extends Control

const CatalogClass = preload("res://ui/widgets/portrait_catalog_system.gd")
const ImportantNpcPortraitSystemClass = preload("res://core/life/important_npc_portrait_system.gd")

const CELL_SIZE := Vector2i(160, 176)
const BACKGROUND := Color("#1c2837")
const VALID_EXPRESSIONS := ["neutral", "happy", "shy", "sad", "angry"]

static var _variant_cache: Dictionary = {}

var character: Dictionary = {}
var expression: String = "neutral"
var _texture: Texture2D
var _combo_key := ""
var _display: TextureRect

func _ready() -> void:
	if custom_minimum_size.x <= 0.0 or custom_minimum_size.y <= 0.0:
		custom_minimum_size = Vector2(200, 220)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_display = TextureRect.new()
	_display.name = "PortraitTexture"
	_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_display.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Keep the texture behind this widget's expression overlay without sending
	# it behind the page/background on Android. Negative z-index made the
	# composed portrait invisible on real devices.
	_display.z_index = 0
	_display.show_behind_parent = true
	add_child(_display)
	_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)
	_refresh_texture()

func set_character(value: Dictionary) -> void:
	character = value
	_refresh_texture()
	queue_redraw()

func set_expression(value: String) -> void:
	expression = value if value in VALID_EXPRESSIONS else "neutral"
	queue_redraw()

func debug_asset_ready() -> bool:
	var standard: Dictionary = CatalogClass.standard_catalog()
	var important: Dictionary = CatalogClass.important_catalog()
	var canvas: Array = standard.get("canvas", [])
	return (
		str(standard.get("version", "")) == "17.0"
		and canvas.size() == 2
		and int(canvas[0]) == 160
		and int(canvas[1]) == 176
		and standard.get("hairstyles", []).size() == 40
		and bool(important.get("hairstyle_pairs_locked", false))
		and important.get("hairstyles", []).size() == 16
		and important.get("roles", []).size() == 41
	)

func debug_variant_texture() -> Texture2D:
	if _texture == null: _refresh_texture()
	return _texture

func debug_variant_hash() -> int:
	if _texture == null: _refresh_texture()
	return hash(_texture.get_image().get_data()) if _texture != null else 0

func debug_combo_key() -> String:
	return _combo_key

func _refresh_texture() -> void:
	if not debug_asset_ready():
		_texture = null
		_sync_display_texture()
		return
	var identity := CatalogClass.identity_for_gender(str(character.get("gender", "Woman")))
	var important_role := str(character.get("important_role", ""))
	var layers: Array[Dictionary] = []
	var important := false
	if not important_role.is_empty() and typeof(character.get("important_portrait", null)) == TYPE_DICTIONARY:
		var ctx := ImportantNpcPortraitSystemClass.context_for(character)
		layers = CatalogClass.resolve_important_layers(character.get("important_portrait", {}), identity, ctx)
		important = not layers.is_empty()
	if not important:
		var appearance: Dictionary = CatalogClass.normalize_standard(character.get("appearance", {}), identity)
		character["appearance"] = appearance
		layers = CatalogClass.resolve_standard_layers(appearance, identity)
	if layers.is_empty():
		_texture = null
		_sync_display_texture()
		return
	var ids: Array[String] = []
	for asset in layers: ids.append(str(asset.get("id", "")))
	_combo_key = ("I:" if important else "S:") + "|".join(ids)
	if _variant_cache.has(_combo_key):
		_texture = _variant_cache[_combo_key]
		_sync_display_texture()
		return
	var image := _compose(layers, important)
	if image == null:
		_texture = null
		_sync_display_texture()
		return
	_texture = ImageTexture.create_from_image(image)
	_variant_cache[_combo_key] = _texture
	_sync_display_texture()

func _sync_display_texture() -> void:
	if _display != null:
		_display.texture = _texture
		_display.visible = _texture != null

func _compose(layers: Array[Dictionary], important: bool) -> Image:
	var image := Image.create(CELL_SIZE.x, CELL_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(BACKGROUND)
	for asset in layers:
		var layer := CatalogClass.load_asset_image(asset, important)
		if layer == null or layer.get_size() != CELL_SIZE:
			return null
		image.blend_rect(layer, Rect2i(Vector2i.ZERO, CELL_SIZE), Vector2i.ZERO)
	return image

func _draw() -> void:
	if _texture == null:
		_refresh_texture()
	if _texture == null:
		return
	var size: Vector2 = get_rect().size
	if size.x <= 1.0 or size.y <= 1.0:
		return
	var ratio := float(CELL_SIZE.x) / float(CELL_SIZE.y)
	var width := size.x
	var height := width / ratio
	if height > size.y:
		height = size.y
		width = height * ratio
	var rect := Rect2((size - Vector2(width, height)) * 0.5, Vector2(width, height))
	_draw_expression_overlay(rect)

func _draw_expression_overlay(rect: Rect2) -> void:
	if expression == "neutral": return
	var scale := minf(rect.size.x / float(CELL_SIZE.x), rect.size.y / float(CELL_SIZE.y))
	var origin := rect.position
	# Expression marks are deliberately tiny overlays. Portrait modules themselves remain unscaled and unmodified.
	match expression:
		"shy":
			_pixel_rect(origin, scale, Rect2(Vector2(48, 94), Vector2(10, 4)), Color(0.93, 0.45, 0.55, 0.20))
			_pixel_rect(origin, scale, Rect2(Vector2(102, 94), Vector2(10, 4)), Color(0.93, 0.45, 0.55, 0.20))
		"sad":
			_pixel_rect(origin, scale, Rect2(Vector2(62, 86), Vector2(2, 7)), Color(0.58, 0.78, 0.96, 0.70))
			_pixel_rect(origin, scale, Rect2(Vector2(96, 86), Vector2(2, 7)), Color(0.58, 0.78, 0.96, 0.70))
		"angry":
			_pixel_line(origin, scale, Vector2(52, 69), Vector2(70, 73), Color("#3f2b32"))
			_pixel_line(origin, scale, Vector2(90, 73), Vector2(108, 69), Color("#3f2b32"))
		"happy":
			_pixel_line(origin, scale, Vector2(75, 111), Vector2(80, 115), Color("#8b4f5a"))
			_pixel_line(origin, scale, Vector2(80, 115), Vector2(85, 111), Color("#8b4f5a"))

func _pixel_rect(origin: Vector2, scale: float, logical: Rect2, color: Color) -> void:
	draw_rect(Rect2(origin + logical.position * scale, logical.size * scale), color)

func _pixel_line(origin: Vector2, scale: float, a: Vector2, b: Vector2, color: Color) -> void:
	draw_line(origin + a * scale, origin + b * scale, color, maxf(1.0, scale), false)