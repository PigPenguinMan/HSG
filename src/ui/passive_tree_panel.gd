class_name PassiveTreePanel
extends PanelContainer

var player: Player
var _canvas: _TreeCanvas
var _header_label: Label
var _tooltip_label: RichTextLabel


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(820, 500)
	_build_ui()


func bind_player(p: Player) -> void:
	player = p
	player.rpg_state_changed.connect(refresh)
	_canvas.player = p
	refresh()


func refresh() -> void:
	if player == null:
		return
	_header_label.text = "본능의 성좌 (패시브 트리) — 잔여 포인트: %d  |  [좌클릭] 습득  [우클릭] 환불  [드래그] 이동  [휠] 줌" % player.passive_points
	_canvas.queue_redraw()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	_header_label = Label.new()
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_label.text = "본능의 성좌"
	top.add_child(_header_label)

	var close_btn := Button.new()
	close_btn.text = "닫기 [P]"
	close_btn.pressed.connect(func(): visible = false)
	top.add_child(close_btn)

	_canvas = _TreeCanvas.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.clip_contents = true
	_canvas.node_hovered.connect(_on_node_hovered)
	vbox.add_child(_canvas)

	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.custom_minimum_size = Vector2(0, 68)
	_tooltip_label.text = "[color=#aaaaaa]노드에 마우스를 올리면 상세 정보가 표시됩니다.[/color]"
	vbox.add_child(_tooltip_label)


func _on_node_hovered(node_data: Dictionary) -> void:
	if node_data.is_empty():
		_tooltip_label.text = "[color=#aaaaaa]노드에 마우스를 올리면 상세 정보가 표시됩니다.[/color]"
		return
	var ntype := str(node_data.get("type", "MINOR"))
	var color := "#ffffff"
	if ntype == "NOTABLE":
		color = "#ffd266"
	elif ntype == "APEX":
		color = "#ff6655"
	var lines: Array[String] = ["[color=%s][b]%s[/b] (%s)[/color]" % [color, str(node_data.get("name", "")), ntype]]
	for s in node_data.get("stats", []):
		lines.append("• %s %s %s" % [str(s.get("stat")), str(s.get("modType")), str(s.get("value"))])
	_tooltip_label.text = "\n".join(lines)


class _TreeCanvas extends Control:
	signal node_hovered(node_data: Dictionary)

	var player: Player
	var pan_offset: Vector2 = Vector2.ZERO
	var zoom_scale: float = 1.0
	var _dragging: bool = false
	var _hovered_id: String = ""

	func _gui_input(event: InputEvent) -> void:
		if player == null:
			return
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
				zoom_scale = clampf(zoom_scale + 0.1, 0.5, 2.0)
				queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
				zoom_scale = clampf(zoom_scale - 0.1, 0.5, 2.0)
				queue_redraw()
			elif mb.button_index == MOUSE_BUTTON_MIDDLE:
				_dragging = mb.pressed
			elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				var hit := _find_node_at(mb.position)
				if hit != "":
					player.allocate_passive(hit)
					queue_redraw()
				else:
					_dragging = true
			elif mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
				_dragging = false
			elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
				var hit := _find_node_at(mb.position)
				if hit != "":
					player.refund_passive(hit)
					queue_redraw()
		elif event is InputEventMouseMotion:
			var mm := event as InputEventMouseMotion
			if _dragging:
				pan_offset += mm.relative
				queue_redraw()
			var hit := _find_node_at(mm.position)
			if hit != _hovered_id:
				_hovered_id = hit
				node_hovered.emit(player.passive_tree.nodes.get(hit, {}))
				queue_redraw()

	func _to_screen(pos_dict: Dictionary) -> Vector2:
		var world_pos := Vector2(float(pos_dict.get("x", 0.0)), float(pos_dict.get("y", 0.0)))
		return size * 0.5 + pan_offset + world_pos * zoom_scale

	func _find_node_at(screen_pos: Vector2) -> String:
		if player == null:
			return ""
		for nid in player.passive_tree.nodes.keys():
			var node: Dictionary = player.passive_tree.nodes[nid]
			var center := _to_screen(node.get("position", {}))
			var radius := _node_radius(str(node.get("type", "MINOR"))) * zoom_scale
			if screen_pos.distance_to(center) <= radius + 4.0:
				return nid
		return ""

	func _node_radius(ntype: String) -> float:
		match ntype:
			"START":
				return 18.0
			"NOTABLE":
				return 15.0
			"APEX":
				return 20.0
			_:
				return 11.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.05, 0.07, 0.96))
		if player == null:
			return
		var tree := player.passive_tree

		# Draw edges
		var drawn_edges := {}
		for nid in tree.nodes.keys():
			var n: Dictionary = tree.nodes[nid]
			var p1 := _to_screen(n.get("position", {}))
			for adj in n.get("adjacentIds", []):
				var aid := str(adj)
				if not tree.nodes.has(aid):
					continue
				var key := "%s_%s" % [nid, aid] if nid < aid else "%s_%s" % [aid, nid]
				if drawn_edges.has(key):
					continue
				drawn_edges[key] = true
				var p2 := _to_screen(tree.nodes[aid].get("position", {}))
				var both_alloc := tree.allocated.has(nid) and tree.allocated.has(aid)
				var col := Color(0.95, 0.3, 0.25) if both_alloc else Color(0.28, 0.26, 0.32)
				draw_line(p1, p2, col, 3.0 if both_alloc else 1.5)

		# Draw nodes
		for nid in tree.nodes.keys():
			var n: Dictionary = tree.nodes[nid]
			var center := _to_screen(n.get("position", {}))
			var r := _node_radius(str(n.get("type", "MINOR"))) * zoom_scale
			var fill := Color(0.18, 0.17, 0.22)
			var border := Color(0.45, 0.45, 0.5)
			if tree.allocated.has(nid):
				fill = Color(0.75, 0.18, 0.18)
				border = Color(1.0, 0.85, 0.35)
			elif tree.can_allocate(nid) and player.passive_points > 0:
				fill = Color(0.2, 0.35, 0.22)
				border = Color(0.45, 0.95, 0.5)
			if nid == _hovered_id:
				border = Color(1.0, 1.0, 1.0)
			draw_circle(center, r, fill)
			draw_arc(center, r, 0.0, TAU, 24, border, 2.0)
