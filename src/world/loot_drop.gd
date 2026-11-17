class_name LootDrop
extends Area2D

signal picked_up(item: Dictionary)
signal pickup_blocked()

var item_data: Dictionary = {}


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	add_child(shape)

	var rarity: int = int(item_data.get("rarity", StatTypes.Rarity.NORMAL))
	var color := _rarity_color(rarity)

	# Loot beam for Magic / Rare
	if rarity != StatTypes.Rarity.NORMAL:
		var beam := ColorRect.new()
		beam.size = Vector2(4, 42)
		beam.position = Vector2(-2, -46)
		beam.color = Color(color.r, color.g, color.b, 0.45)
		add_child(beam)

	var icon := ColorRect.new()
	icon.size = Vector2(12, 12)
	icon.position = Vector2(-6, -6)
	icon.color = color
	add_child(icon)

	var label := Label.new()
	label.text = _format_name()
	label.position = Vector2(-48, -28)
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 11)
	add_child(label)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node) -> void:
	if body is Player:
		if body.add_item_to_inventory(item_data):
			picked_up.emit(item_data)
			queue_free()
		else:
			pickup_blocked.emit()


func _rarity_color(rarity: int) -> Color:
	match rarity:
		StatTypes.Rarity.MAGIC:
			return Color(0.45, 0.65, 1.0)
		StatTypes.Rarity.RARE:
			return Color(1.0, 0.85, 0.25)
		_:
			return Color(0.85, 0.85, 0.85)


func _format_name() -> String:
	var base := str(item_data.get("baseId", "item")).replace("base_", "").capitalize()
	var rarity: int = int(item_data.get("rarity", StatTypes.Rarity.NORMAL))
	match rarity:
		StatTypes.Rarity.MAGIC:
			return "[마법] " + base
		StatTypes.Rarity.RARE:
			return "[희귀] " + base
		_:
			return base
