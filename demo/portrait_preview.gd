extends Control
## Independently illustrated layered portrait preview, not the private game's sprites.
## Back hair, shoulders, skin, face, eyes and paired front hair are drawn in order.

var gender: String = "Woman"
var hair: int = 0
var skin: int = 1

func _ready() -> void:
    custom_minimum_size = Vector2(0, 265)
    queue_redraw()

func _shape(points: Array, fill: Color) -> void:
    draw_colored_polygon(PackedVector2Array(points), fill)

func _draw() -> void:
    var s: float = minf(size.x / 160.0, size.y / 176.0)
    var offset := Vector2((size.x - 160.0 * s) * 0.5, (size.y - 176.0 * s) * 0.5)
    draw_set_transform(offset, 0.0, Vector2(s, s))
    var night := Color("#172737")
    var haze := Color("#2c4155")
    draw_rect(Rect2(1, 1, 158, 174), night)
    draw_rect(Rect2(5, 5, 150, 166), haze)
    draw_circle(Vector2(80, 80), 59, Color("#3a5664"))
    draw_circle(Vector2(80, 77), 48, Color("#4a6570"))
    draw_rect(Rect2(8, 148, 144, 4), Color("#c2a071"))
    draw_rect(Rect2(8, 151, 144, 18), Color("#20303d"))
    for x in [14, 28, 136, 147]:
        draw_circle(Vector2(x, 16), 1.5, Color("#d6b47c"))
    var complexion: Array = [Color("#f2cbb2"), Color("#d9a17e"), Color("#98674f")]
    var face: Color = complexion[clampi(skin, 0, 2)]
    var shadow: Color = face.darkened(0.16)
    var light: Color = face.lightened(0.15)
    var hair_palette: Array = [Color("#252638"), Color("#8a533e"), Color("#e0c18b"), Color("#b3bac7")]
    var hcol: Color = hair_palette[posmod(hair, 4)]
    var hshade: Color = hcol.darkened(0.23)
    var hlight: Color = hcol.lightened(0.20)
    var robe: Color = Color("#435f77") if gender == "Woman" else Color("#52616a")
    var robe_shadow: Color = robe.darkened(0.27)
    # Hair at the back: soft pixel-stepped silhouette, paired with the front style.
    _shape([Vector2(48, 56),Vector2(55, 36),Vector2(69, 27),Vector2(92, 27),Vector2(106, 40),
            Vector2(113, 58),Vector2(111, 101),Vector2(117, 125),Vector2(109, 143),
            Vector2(99, 136),Vector2(91, 124),Vector2(62, 124),Vector2(50, 142),
            Vector2(42, 137),Vector2(45, 105)], hshade)
    if gender == "Woman":
        _shape([Vector2(48, 66),Vector2(56, 68),Vector2(55, 120),Vector2(44, 136),
            Vector2(36, 124),Vector2(42, 85)], hcol)
        _shape([Vector2(103, 66),Vector2(114, 73),Vector2(119, 121),Vector2(110, 142),
            Vector2(103, 134),Vector2(101, 102)], hcol)
    # Shoulders and sleeves have distinct faceted folds.
    _shape([Vector2(55, 118),Vector2(39, 120),Vector2(28, 133),Vector2(20, 169),
            Vector2(140, 169),Vector2(132, 133),Vector2(116, 120),Vector2(101, 118)], robe_shadow)
    _shape([Vector2(60, 118),Vector2(42, 126),Vector2(34, 145),Vector2(32, 169),
            Vector2(128, 169),Vector2(126, 145),Vector2(112, 126),Vector2(100, 118)], robe)
    _shape([Vector2(55, 124),Vector2(76, 139),Vector2(76, 169),Vector2(53, 169),
            Vector2(50, 146)], robe.lightened(0.09))
    _shape([Vector2(104, 124),Vector2(84, 139),Vector2(84, 169),Vector2(108, 169),
            Vector2(111, 146)], robe.darkened(0.09))
    _shape([Vector2(65, 116),Vector2(71, 130),Vector2(80, 137),Vector2(88, 130),
            Vector2(94, 116)], Color("#f2e1bf"))
    _shape([Vector2(70, 103),Vector2(70, 121),Vector2(80, 132),
            Vector2(90, 121),Vector2(90, 103)], shadow)
    _shape([Vector2(75, 112),Vector2(75, 124),Vector2(80, 130),
            Vector2(85, 124),Vector2(85, 112)], face)
    # Ears and a tapered, human face (rather than rectangular blocks).
    draw_circle(Vector2(52, 85), 7.0, shadow)
    draw_circle(Vector2(108, 85), 7.0, shadow)
    _shape([Vector2(55, 55),Vector2(65, 47),Vector2(94, 47),Vector2(104, 56),
            Vector2(105, 92),Vector2(100, 109),Vector2(91, 120),
            Vector2(80, 125),Vector2(69, 120),Vector2(59, 109),
            Vector2(54, 91)], shadow)
    _shape([Vector2(60, 53),Vector2(69, 49),Vector2(92, 49),Vector2(101, 59),
            Vector2(102, 90),Vector2(97, 106),Vector2(89, 116),
            Vector2(80, 120),Vector2(70, 116),Vector2(62, 105),
            Vector2(58, 87)], face)
    _shape([Vector2(62, 60),Vector2(73, 54),Vector2(85, 55),Vector2(77, 77),
            Vector2(63, 89)], light)
    # Brows, lashes, irises and distinct lip/nose details.
    draw_line(Vector2(64, 80), Vector2(75, 78), hshade, 2.4)
    draw_line(Vector2(87, 78), Vector2(97, 80), hshade, 2.4)
    draw_line(Vector2(64, 86), Vector2(76, 86), Color("#2a2c34"), 2.5)
    draw_line(Vector2(87, 86), Vector2(99, 86), Color("#2a2c34"), 2.5)
    draw_circle(Vector2(71, 87), 3.0, Color("#496b76"))
    draw_circle(Vector2(93, 87), 3.0, Color("#496b76"))
    draw_circle(Vector2(72, 86), 1.0, Color("#ffffff"))
    draw_circle(Vector2(94, 86), 1.0, Color("#ffffff"))
    if gender == "Woman":
        draw_line(Vector2(64, 85), Vector2(61, 82), Color("#292c36"), 1.3)
        draw_line(Vector2(99, 85), Vector2(102, 82), Color("#292c36"), 1.3)
    draw_line(Vector2(80, 90), Vector2(78, 101), shadow, 1.5)
    draw_line(Vector2(77, 103), Vector2(83, 103), shadow.darkened(0.15), 1.6)
    draw_line(Vector2(75, 112), Vector2(84, 113), Color("#ac6568"), 2.0)
    draw_line(Vector2(78, 115), Vector2(83, 115), Color("#e6a09a"), 1.0)
    # Front hair: four paired silhouettes with their own fixed colors.
    if posmod(hair, 4) == 0:
        _shape([Vector2(49, 71),Vector2(50, 51),Vector2(58, 38),
            Vector2(77, 30),Vector2(97, 35),Vector2(109, 48),Vector2(106, 74),
            Vector2(101, 67),Vector2(99, 54),Vector2(90, 48),
            Vector2(82, 62),Vector2(71, 68),Vector2(63, 56),
            Vector2(57, 74)], hcol)
        _shape([Vector2(61, 43),Vector2(77, 35),Vector2(90, 39),
            Vector2(78, 49),Vector2(68, 52)], hlight)
    elif posmod(hair, 4) == 1:
        _shape([Vector2(48, 71),Vector2(52, 46),Vector2(62, 35),
            Vector2(88, 30),Vector2(108, 42),Vector2(111, 66),
            Vector2(103, 64),Vector2(94, 47),Vector2(82, 52),
            Vector2(74, 65),Vector2(64, 58),Vector2(58, 77)], hcol)
        _shape([Vector2(62, 38),Vector2(90, 34),Vector2(99, 41),
            Vector2(81, 43),Vector2(73, 57),Vector2(67, 52)], hlight)
        if gender == "Woman":
            _shape([Vector2(101, 61),Vector2(110, 72),Vector2(111, 128),
                Vector2(105, 138),Vector2(102, 117)], hcol)
    elif posmod(hair, 4) == 2:
        _shape([Vector2(50, 66),Vector2(56, 43),Vector2(68, 31),
            Vector2(93, 31),Vector2(105, 43),Vector2(110, 70),
            Vector2(101, 69),Vector2(97, 55),Vector2(86, 62),
            Vector2(77, 72),Vector2(67, 59),Vector2(56, 78)], hcol)
        _shape([Vector2(68, 37),Vector2(88, 34),Vector2(99, 43),
            Vector2(83, 49),Vector2(76, 62)], hlight)
        draw_line(Vector2(80, 44), Vector2(68, 62), hshade, 2.0)
    else:
        _shape([Vector2(47, 67),Vector2(52, 44),Vector2(63, 33),
            Vector2(84, 29),Vector2(102, 38),Vector2(112, 55),
            Vector2(105, 75),Vector2(101, 66),Vector2(95, 50),
            Vector2(82, 54),Vector2(72, 67),Vector2(63, 54),
            Vector2(57, 76)], hcol)
        _shape([Vector2(57, 48),Vector2(70, 38),Vector2(90, 34),
            Vector2(104, 42),Vector2(85, 46),Vector2(68, 61)], hlight)
        if gender == "Woman":
            _shape([Vector2(48, 67),Vector2(47, 113),Vector2(41, 127),
                Vector2(48, 139),Vector2(57, 128),Vector2(56, 86)], hcol)
    # Lapels and neckline with a metal clasp.
    draw_line(Vector2(58, 126), Vector2(78, 150), Color("#c9a46d"), 2.0)
    draw_line(Vector2(103, 126), Vector2(83, 150), Color("#c9a46d"), 2.0)
    draw_circle(Vector2(80, 150), 3.0, Color("#eac98b"))
    draw_circle(Vector2(80, 150), 1.2, Color("#637e9a"))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
