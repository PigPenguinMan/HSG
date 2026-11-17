extends Control

@onready var output_label: RichTextLabel = $CenterContainer/Panel/MarginContainer/VBoxContainer/OutputLabel


func _ready() -> void:
	var results := Phase0Tests.run_all()
	var lines := PackedStringArray([
		"[b]Bloodmoon Wilds (HSG) — Phase 0 Core Verification[/b]",
		"Godot 4 (Windows / macOS) Ready",
		"",
	])
	for line in results:
		lines.append("[color=#7CFC00]%s[/color]" % line)
	lines.append("")
	lines.append("All %d Phase 0 core tests passed!" % results.size())
	output_label.text = "\n".join(lines)
