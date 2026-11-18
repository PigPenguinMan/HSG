class_name InventoryPanel
extends PanelContainer

var player: Player
var _selected_currency: int = -1

var _stats_label: RichTextLabel
var _tooltip_label: RichTextLabel
var _equip_buttons: Dictionary = {}
var _inv_buttons: Array[Button] = []
var _currency_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	custom_minimum_size = Vector2(820, 480)
	_build_ui()


func bind_player(p: Player) -> void:
	player = p
	player.rpg_state_changed.connect(refresh)
	refresh()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 10)
	margin.add_child(root_vbox)

	var header := HBoxContainer.new()
	root_vbox.add_child(header)
	var title := Label.new()
	title.text = "장비 & 슬롯형 인벤토리 / 혈석 크래프팅 (I)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close_btn := Button.new()
	close_btn.text = "닫기 [I]"
	close_btn.pressed.connect(func(): visible = false)
	header.add_child(close_btn)

	var main_hbox := HBoxContainer.new()
	main_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_hbox.add_theme_constant_override("separation", 16)
	root_vbox.add_child(main_hbox)

	# Left: Equipment + Stats
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(270, 0)
	left_vbox.add_theme_constant_override("separation", 6)
	main_hbox.add_child(left_vbox)

	var eq_title := Label.new()
	eq_title.text = "장착 장비 (클릭 시 해제)"
	left_vbox.add_child(eq_title)

	var slot_labels := {
		"WEAPON": "무기",
		"ARMOUR": "갑옷",
		"BOOTS": "장화",
		"RING_1": "반지 1",
		"RING_2": "반지 2",
		"AMULET": "목걸이",
	}
	for slot_key in ["WEAPON", "ARMOUR", "BOOTS", "RING_1", "RING_2", "AMULET"]:
		var btn := Button.new()
		btn.text = "%s: [비어있음]" % slot_labels[slot_key]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.pressed.connect(func(): _on_equip_slot_clicked(slot_key))
		btn.mouse_entered.connect(func(): _show_equip_tooltip(slot_key))
		left_vbox.add_child(btn)
		_equip_buttons[slot_key] = btn

	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stats_label.text = ""
	left_vbox.add_child(_stats_label)

	# Right: 6x4 Uniform Inventory Grid + Tooltip
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 8)
	main_hbox.add_child(right_vbox)

	var inv_title := Label.new()
	inv_title.text = "인벤토리 (1x1 슬롯, 클릭: 장착 / 혈석 선택 후 클릭: 크래프팅)"
	right_vbox.add_child(inv_title)

	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	right_vbox.add_child(grid)

	for i in range(Player.MAX_INVENTORY_SLOTS):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(78, 44)
		btn.text = "-"
		btn.clip_text = true
		btn.pressed.connect(func(): _on_inv_slot_clicked(i))
		btn.mouse_entered.connect(func(): _show_inv_tooltip(i))
		grid.add_child(btn)
		_inv_buttons.append(btn)

	_tooltip_label = RichTextLabel.new()
	_tooltip_label.bbcode_enabled = true
	_tooltip_label.custom_minimum_size = Vector2(0, 105)
	_tooltip_label.text = "[color=#aaaaaa]아이템에 마우스를 올리면 상세 옵션이 표시됩니다.[/color]"
	right_vbox.add_child(_tooltip_label)

	# Bottom: Currency Bar
	var cur_hbox := HBoxContainer.new()
	cur_hbox.add_theme_constant_override("separation", 8)
	root_vbox.add_child(cur_hbox)

	var currencies := [
		[StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT, "변이(일반→마법)"],
		[StatTypes.CurrencyType.BLOODSTONE_OF_FORGE, "연금(일반→희귀)"],
		[StatTypes.CurrencyType.BLOODSTONE_OF_RUIN, "혼돈(희귀 재굴림)"],
		[StatTypes.CurrencyType.BLOODSTONE_OF_PURGE, "정화(→일반)"],
		[StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH, "고결(옵션+1)"],
	]
	for c in currencies:
		var ctype: int = c[0]
		var cname: String = c[1]
		var btn := Button.new()
		btn.toggle_mode = true
		btn.text = "%s: 0" % cname
		btn.pressed.connect(func(): _on_currency_toggled(ctype, btn))
		cur_hbox.add_child(btn)
		_currency_buttons[ctype] = btn


func refresh() -> void:
	if player == null or not is_node_ready():
		return

	var slot_labels := {
		"WEAPON": "무기", "ARMOUR": "갑옷", "BOOTS": "장화",
		"RING_1": "반지 1", "RING_2": "반지 2", "AMULET": "목걸이",
	}
	for slot_key in _equip_buttons.keys():
		var btn: Button = _equip_buttons[slot_key]
		var item: Variant = player.equipment.get(slot_key)
		if item is Dictionary:
			btn.text = "%s: %s" % [slot_labels[slot_key], _short_item_name(item)]
			btn.modulate = _rarity_color(int(item.get("rarity", 0)))
		else:
			btn.text = "%s: [비어있음]" % slot_labels[slot_key]
			btn.modulate = Color(0.75, 0.75, 0.75)

	for i in range(_inv_buttons.size()):
		var btn: Button = _inv_buttons[i]
		if i < player.inventory.size():
			var item: Dictionary = player.inventory[i]
			btn.text = _short_item_name(item)
			btn.modulate = _rarity_color(int(item.get("rarity", 0)))
			btn.disabled = false
		else:
			btn.text = ""
			btn.modulate = Color(0.5, 0.5, 0.5)
			btn.disabled = true

	var cur_names := {
		StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT: "변이",
		StatTypes.CurrencyType.BLOODSTONE_OF_FORGE: "연금",
		StatTypes.CurrencyType.BLOODSTONE_OF_RUIN: "혼돈",
		StatTypes.CurrencyType.BLOODSTONE_OF_PURGE: "정화",
		StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH: "고결",
	}
	for ctype in _currency_buttons.keys():
		var btn: Button = _currency_buttons[ctype]
		var cnt: int = int(player.currency_pouch.get(ctype, 0))
		btn.text = "%s (%d)" % [cur_names[ctype], cnt]
		btn.button_pressed = (_selected_currency == ctype)

	var attrs := player.stats.compute_attributes(14.0, 24.0, 10.0)
	var phys_inc := (player.stats.get_stat("PHYSICAL_DAMAGE", 1.0) - 1.0) * 100.0
	var bleed := player.stats.get_stat("BLEED_CHANCE", 0.0)
	_stats_label.text = "[b]캐릭터 스탯 (Lv.%d)[/b]\nSTR %d | DEX %d | INT %d\n최대 생명력: %d | 방어도: %d\n물리 피해 증가: +%d%% | 출혈 확률: %d%%\n이동 속도: %d" % [
		player.level, int(attrs["STR"]), int(attrs["DEX"]), int(attrs["INT"]),
		int(player.max_hp), int(player.armour), int(phys_inc), int(bleed), int(player.move_speed)
	]


func _on_equip_slot_clicked(slot_key: String) -> void:
	if player != null:
		player.unequip_slot(slot_key)


func _on_inv_slot_clicked(idx: int) -> void:
	if player == null or idx >= player.inventory.size():
		return
	if _selected_currency != -1:
		player.apply_currency_to_inventory(idx, _selected_currency)
		_show_inv_tooltip(idx)
	else:
		player.equip_from_inventory(idx)


func _on_currency_toggled(ctype: int, _btn: Button) -> void:
	_selected_currency = -1 if _selected_currency == ctype else ctype
	refresh()


func _show_equip_tooltip(slot_key: String) -> void:
	if player == null:
		return
	var item: Variant = player.equipment.get(slot_key)
	if item is Dictionary:
		_tooltip_label.text = _format_tooltip(item)


func _show_inv_tooltip(idx: int) -> void:
	if player == null or idx >= player.inventory.size():
		return
	_tooltip_label.text = _format_tooltip(player.inventory[idx])


func _format_tooltip(item: Dictionary) -> String:
	var rarity: int = int(item.get("rarity", 0))
	var hex := "#dddddd"
	if rarity == StatTypes.Rarity.MAGIC:
		hex = "#77aaff"
	elif rarity == StatTypes.Rarity.RARE:
		hex = "#ffdd55"
	var lines: Array[String] = ["[color=%s][b]%s[/b][/color] (iLvl %d)" % [hex, _short_item_name(item), int(item.get("itemLevel", 1))]]
	for p in item.get("prefixes", []):
		lines.append("[color=#aaccff]• [접두] %s[/color]" % StatTypes.format_stat(str(p["stat"]), str(p.get("modType", "FLAT")), float(p["value"])))
	for s in item.get("suffixes", []):
		lines.append("[color=#ccffaa]• [접미] %s[/color]" % StatTypes.format_stat(str(s["stat"]), str(s.get("modType", "FLAT")), float(s["value"])))
	if item.get("prefixes", []).is_empty() and item.get("suffixes", []).is_empty():
		lines.append("[color=#888888]옵션 없음 (혈석으로 제작 가능)[/color]")
	return "\n".join(lines)


func _short_item_name(item: Dictionary) -> String:
	return str(item.get("slot", "ITEM"))


func _rarity_color(rarity: int) -> Color:
	match rarity:
		StatTypes.Rarity.MAGIC:
			return Color(0.55, 0.75, 1.0)
		StatTypes.Rarity.RARE:
			return Color(1.0, 0.88, 0.35)
		_:
			return Color(0.9, 0.9, 0.9)
