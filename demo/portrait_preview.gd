extends Control
## Simplified pixel-style silhouette for this showcase; NOT the private P92 portrait assets.

var gender: String = "Woman"
var hair: int = 0

func _ready() -> void:
    custom_minimum_size = Vector2(280, 240)
    queue_redraw()

func _draw() -> void:
    var scale_factor: float = minf(size.x / 280.0, size.y / 240.0)
    var offset := Vector2((size.x - 280.0 * scale_factor) * 0.5, (size.y - 240.0 * scale_factor) * 0.5)
    draw_set_transform(offset, 0.0, Vector2(scale_factor, scale_factor))
    draw_rect(Rect2(27, 6, 226, 228), Color("#1d2b42"))
    draw_rect(Rect2(40, 18, 200, 203), Color("#273c53"))
    var skin := Color("#dfaa84") if gender == "Woman" else Color("#bf8669")
    var cloth := Color("#6f8cae") if gender == "Woman" else Color("#786ba9")
    var hcol: Color = [Color("#282339"), Color("#957041"), Color("#c7c9d2")][hair % 3]
    draw_rect(Rect2(71, 179, 138, 34), cloth)
    draw_rect(Rect2(83, 154, 114, 59), cloth)
    draw_rect(Rect2(119, 147, 42, 40), skin)
    draw_rect(Rect2(91, 52, 98, 107), hcol)
    draw_rect(Rect2(105, 63, 70, 95), skin)
    draw_rect(Rect2(99, 41, 83, 37), hcol)
    if hair % 3 == 1:
        draw_rect(Rect2(94, 72, 18, 68), hcol)
    elif hair % 3 == 2:
        draw_rect(Rect2(172, 59, 18, 91), hcol)
    draw_rect(Rect2(118, 113, 11, 7), Color("#26354c"))
    draw_rect(Rect2(153, 113, 11, 7), Color("#26354c"))
    draw_rect(Rect2(136, 139, 13, 4), Color("#995d62"))
    draw_rect(Rect2(78, 206, 124, 7), Color("#d4b77c"))
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
