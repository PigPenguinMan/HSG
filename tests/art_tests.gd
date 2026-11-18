extends RefCounted
## Paper-doll layer tests for the wolf player (assets/sprites/wolf/, built by tools/art/split_wolf_layers.py).

const T := preload("res://tests/test_check.gd")
const DIR: String = "res://assets/sprites/wolf/"


static func test_names() -> Array[String]:
	return [
		"_test_wolf_layers_recompose_to_sprite",
		"_test_wolf_layer_meta",
	]


static func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	if img != null:
		img.convert(Image.FORMAT_RGBA8)
	return img


static func _test_wolf_layers_recompose_to_sprite() -> String:
	var full := _load("res://assets/sprites/wolf_player.png")
	var base := _load(DIR + "base.png")
	var outfit := _load(DIR + "outfit_default.png")
	var scarf := _load(DIR + "scarf.png")
	for pair in [["wolf_player", full], ["base", base], ["outfit_default", outfit], ["scarf", scarf]]:
		if not T.ok(pair[1] != null, "%s.png loads" % pair[0]):
			return "Wolf layers recompose"
		T.eq((pair[1] as Image).get_size(), full.get_size(), "%s.png size matches wolf_player.png" % pair[0])

	var comp := Image.create(full.get_width(), full.get_height(), false, Image.FORMAT_RGBA8)
	var rect := Rect2i(Vector2i.ZERO, full.get_size())
	for layer in [base, outfit, scarf]:
		comp.blend_rect(layer, rect, Vector2i.ZERO)
	var diff: int = 0
	for y in range(full.get_height()):
		for x in range(full.get_width()):
			if not comp.get_pixel(x, y).is_equal_approx(full.get_pixel(x, y)):
				diff += 1
	T.eq(diff, 0, "pixels that differ between base+outfit+scarf and wolf_player.png")

	# The cloak must hide the whole fur torso, so armour layers can rely on the same footprint.
	var torso_visible: int = 0
	for y in range(full.get_height()):
		for x in range(full.get_width()):
			if outfit.get_pixel(x, y).a > 0.0 and scarf.get_pixel(x, y).a == 0.0 and base.get_pixel(x, y).a == 0.0:
				torso_visible += 1
	T.eq(torso_visible, 0, "outfit pixels with no body underneath")
	return "Wolf layers: base + outfit_default + scarf == wolf_player.png (pixel exact)"


static func _test_wolf_layer_meta() -> String:
	var text := FileAccess.get_file_as_string(DIR + "layers.json")
	var meta: Variant = JSON.parse_string(text)
	if not T.ok(meta is Dictionary, "layers.json parses"):
		return "Wolf layer meta"
	var d: Dictionary = meta
	T.eq(int(d.get("frames", 0)), 2, "2 frames")
	var anchors: Array = d.get("weapon_anchor", [])
	T.eq(anchors.size(), 2, "one weapon anchor per frame")
	var base := _load(DIR + "base.png")
	for a in anchors:
		var hand: Array = a.get("hand", [])
		var hx: int = int(hand[0])
		var hy: int = int(hand[1])
		T.ok(hx >= 0 and hx < 32 and hy >= 0 and hy < 32, "anchor inside the 32x32 frame")
		# The hand sits just right of the torso: the pixel to its left is part of the body.
		var fx: int = int(a.get("frame", 0)) * 32
		T.ok(base.get_pixel(fx + hx - 1, hy).a > 0.0, "frame %d anchor touches the body" % int(a.get("frame", 0)))
	return "Wolf layer meta: 2 frames, weapon anchors inside frame and next to the body"
