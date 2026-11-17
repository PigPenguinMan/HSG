class_name SkillPanel
extends PanelContainer

var player: Player
var _slot_list: VBoxContainer
var _info_label: RichTextLabel


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(720, 440)
	_build_ui()


func bind_player(p: Player) -> void:
	player = p
	player.rpg_state_changed.connect(refresh)
	refresh()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	var top := HBoxContainer.new()
	vbox.add_child(top)
	var title := Label.new()
	title.text = "스킬 & 보조 룬 링크 (슬롯당 최대 3보조)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "닫기 [K]"
	close_btn.pressed.connect(func(): visible = false)
	top.add_child(close_btn)

	_slot_list = VBoxContainer.new()
	_slot_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_slot_list.add_theme_constant_override("separation", 10)
	vbox.add_child(_slot_list)

	_info_label = RichTextLabel.new()
	_info_label.bbcode_enabled = true
	_info_label.custom_minimum_size = Vector2(0, 56)
	_info_label.text = "[color=#aaaaaa]태그가 일치하는 보조 룬만 연결할 수 있습니다.[/color]"
	vbox.add_child(_info_label)


func refresh() -> void:
	if player == null or not is_node_ready():
		return
	for c in _slot_list.get_children():
		c.queue_free()

	var slot_labels := {
		"LMB": "좌클릭",
		"RMB": "우클릭",
		"Q": "Q 스킬",
		"SPACE": "Space 이동",
	}
	var combat_skills := ["crimson_flurry", "crushing_slam", "piercing_fang", "bloodmoon_orb"]

	for slot_key in ["LMB", "RMB", "Q", "SPACE"]:
		var slot: Dictionary = player.skill_slots[slot_key]
		var sid := str(slot["skill_id"])
		var sdef: Dictionary = player.skills_db.get(sid, {})
		var linked: Array = slot["runes"]

		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		_slot_list.add_child(row)

		var header := HBoxContainer.new()
		header.add_theme_constant_override("separation", 8)
		row.add_child(header)

		var k_lbl := Label.new()
		k_lbl.text = "[%s] %s" % [slot_labels[slot_key], str(sdef.get("name", sid))]
		k_lbl.custom_minimum_size = Vector2(180, 0)
		header.add_child(k_lbl)

		if slot_key != "SPACE":
			for cid in combat_skills:
				var cdef: Dictionary = player.skills_db.get(cid, {})
				var btn := Button.new()
				btn.text = str(cdef.get("name", cid))
				btn.disabled = (cid == sid)
				var sk := str(slot_key)
				var target_id := str(cid)
				btn.pressed.connect(func() -> void: player.set_slot_skill(sk, target_id))
				btn.mouse_entered.connect(func() -> void: _show_skill_info(cdef))
				header.add_child(btn)
		else:
			var tag_lbl := Label.new()
			tag_lbl.text = "태그: " + ", ".join(sdef.get("tags", []))
			tag_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
			header.add_child(tag_lbl)

		var rune_bar := HBoxContainer.new()
		rune_bar.add_theme_constant_override("separation", 6)
		row.add_child(rune_bar)

		var r_title := Label.new()
		r_title.text = "  보조 룬 (%d/3):" % linked.size()
		r_title.custom_minimum_size = Vector2(120, 0)
		rune_bar.add_child(r_title)

		for rid in player.runes_db.keys():
			var rdef: Dictionary = player.runes_db[rid]
			var compat := player.can_link_rune(sid, str(rid))
			var is_on := linked.has(rid)
			var rbtn := Button.new()
			rbtn.text = ("✓ " if is_on else "") + str(rdef.get("name", rid))
			rbtn.disabled = (not compat and not is_on)
			var sk := str(slot_key)
			var target_rid := str(rid)
			rbtn.pressed.connect(func() -> void: player.toggle_rune(sk, target_rid))
			rbtn.mouse_entered.connect(func() -> void: _show_rune_info(rdef, compat))
			rune_bar.add_child(rbtn)


func _show_skill_info(sdef: Dictionary) -> void:
	_info_label.text = "[b]%s[/b]  [color=#88ccff][%s][/color]\n%s" % [
		str(sdef.get("name", "")),
		", ".join(sdef.get("tags", [])),
		str(sdef.get("desc", "")),
	]


func _show_rune_info(rdef: Dictionary, compat: bool) -> void:
	var note := "[color=#88ff88]장착 가능[/color]" if compat else "[color=#ff6666]태그 불일치 (장착 불가)[/color]"
	_info_label.text = "[b]%s[/b]  —  %s\n%s" % [
		str(rdef.get("name", "")),
		note,
		str(rdef.get("desc", "")),
	]
