class_name PassiveTreeGraph
extends RefCounted

var nodes: Dictionary = {}       # node_id -> Dictionary
var allocated: Dictionary = {}   # node_id -> true
var start_node_id: String = ""


func load_from_dict(data: Dictionary) -> void:
	nodes.clear()
	allocated.clear()
	start_node_id = ""

	var node_list: Array = data.get("nodes", [])
	for n in node_list:
		var nid: String = str(n.get("id", ""))
		if nid == "":
			continue
		nodes[nid] = n
		if n.get("type") == "START" and start_node_id == "":
			start_node_id = nid

	if start_node_id != "":
		allocated[start_node_id] = true


func load_from_json_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		load_from_dict(parsed)
		return true
	return false


func can_allocate(node_id: String) -> bool:
	if not nodes.has(node_id) or allocated.has(node_id):
		return false
	var adj: Array = nodes[node_id].get("adjacentIds", [])
	for neighbor_id in adj:
		if allocated.has(str(neighbor_id)):
			return true
	return false


func allocate(node_id: String) -> bool:
	if not can_allocate(node_id):
		return false
	allocated[node_id] = true
	return true


func can_refund(node_id: String) -> bool:
	if node_id == start_node_id or not allocated.has(node_id):
		return false

	# BFS from start_node_id excluding node_id to prevent orphan islands
	var visited: Dictionary = {start_node_id: true}
	var queue: Array[String] = [start_node_id]
	var head: int = 0

	while head < queue.size():
		var curr: String = queue[head]
		head += 1
		var adj: Array = nodes[curr].get("adjacentIds", [])
		for neighbor in adj:
			var nid: String = str(neighbor)
			if nid == node_id or visited.has(nid) or not allocated.has(nid):
				continue
			visited[nid] = true
			queue.append(nid)

	# All remaining allocated nodes (total allocated - 1) must be reachable
	return visited.size() == allocated.size() - 1


func refund(node_id: String) -> bool:
	if not can_refund(node_id):
		return false
	allocated.erase(node_id)
	return true


func collect_modifiers(aggregator: StatAggregator) -> void:
	for nid in allocated.keys():
		var node: Dictionary = nodes[nid]
		var stats: Array = node.get("stats", [])
		for s in stats:
			var mtype := StatTypes.ModType.FLAT
			match str(s.get("modType", "FLAT")):
				"INCREASED":
					mtype = StatTypes.ModType.INCREASED
				"MORE":
					mtype = StatTypes.ModType.MORE
				"FLAG":
					mtype = StatTypes.ModType.FLAG
			aggregator.add_modifier(StatTypes.make_mod(
				str(s.get("stat", "")),
				mtype,
				float(s.get("value", 0.0)),
				"passive:" + nid,
				s.get("tags", [])
			))
