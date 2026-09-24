class_name Socketing
extends RefCounted

## 將材料鑲入物品的純邏輯；材料扣減由 GameState 負責，避免節點依賴。

static func normalize_item(item: Dictionary) -> Dictionary:
	var normalized: Dictionary = item.duplicate(true)
	var sockets: Array = []
	var raw_sockets: Array = item.get("sockets", [])
	for raw_socket: Variant in raw_sockets:
		if not (raw_socket is Dictionary):
			continue
		var source: Dictionary = raw_socket
		var socket_type: String = str(source.get("type", ""))
		if not Materials.MATERIAL_TYPES.has(socket_type):
			continue
		var normalized_socket: Dictionary = {"type": socket_type, "material_id": null, "level": 0, "rarity": ""}
		var material_id: String = _get_socket_material_id(source)
		if Materials.get_material_definition(material_id).size() > 0 and Materials.get_socket_type(material_id) == socket_type:
			normalized_socket["material_id"] = material_id
			normalized_socket["level"] = maxi(1, int(source.get("level", 1)))
			normalized_socket["rarity"] = str(source.get("rarity", Materials.get_rarity(material_id)))
		sockets.append(normalized_socket)
	normalized["sockets"] = sockets
	return normalized

static func get_socket_count(item: Dictionary) -> int:
	return item.get("sockets", []).size() if item.get("sockets", []) is Array else 0

static func get_empty_socket_index(item: Dictionary, socket_type: String = "") -> int:
	var sockets: Array = item.get("sockets", [])
	for index: int in range(sockets.size()):
		var socket: Dictionary = sockets[index]
		if not _get_socket_material_id(socket).is_empty():
			continue
		if socket_type.is_empty() or str(socket.get("type", "")) == socket_type:
			return index
	return -1

static func can_socket(item: Dictionary, socket_index: int, material: Variant) -> Dictionary:
	var sockets: Array = item.get("sockets", [])
	if socket_index < 0 or socket_index >= sockets.size():
		return {"ok": false, "reason": "invalid_socket"}
	var material_id: String = str(material.get("id", material)) if material is Dictionary else str(material)
	var definition: Dictionary = Materials.get_material_definition(material_id)
	if definition.is_empty():
		return {"ok": false, "reason": "unknown_material"}
	var socket: Dictionary = sockets[socket_index]
	if not _get_socket_material_id(socket).is_empty():
		return {"ok": false, "reason": "socket_occupied"}
	if str(socket.get("type", "")) != str(definition.get("type", "")):
		return {"ok": false, "reason": "socket_type_mismatch"}
	return {"ok": true, "reason": "ready", "material_id": material_id}

static func socket_material(item: Dictionary, socket_index: int, material: Variant) -> Dictionary:
	var normalized: Dictionary = normalize_item(item)
	var check: Dictionary = can_socket(normalized, socket_index, material)
	if not bool(check.get("ok", false)):
		return {"ok": false, "item": normalized, "material": {}, "reason": str(check.get("reason", "invalid_socket"))}
	var material_id: String = str(check.get("material_id", ""))
	var material_definition: Dictionary = Materials.get_material_definition(material_id)
	var level: int = int((material as Dictionary).get("level", 1)) if material is Dictionary else 1
	var rarity_id: String = str((material as Dictionary).get("rarity", "")) if material is Dictionary else Materials.get_rarity(material_id)
	if rarity_id.is_empty():
		rarity_id = Materials.get_rarity(material_id)
	var sockets: Array = normalized["sockets"]
	sockets[socket_index]["material_id"] = material_id
	sockets[socket_index]["material_name"] = str(material_definition.get("name", material_id))
	sockets[socket_index]["level"] = maxi(1, level)
	sockets[socket_index]["rarity"] = rarity_id
	return {"ok": true, "item": normalized, "material_id": material_id, "material": sockets[socket_index], "reason": "socketed"}

static func unsocket_material(item: Dictionary, socket_index: int) -> Dictionary:
	var normalized: Dictionary = normalize_item(item)
	var sockets: Array = normalized.get("sockets", [])
	if socket_index < 0 or socket_index >= sockets.size():
		return {"ok": false, "item": normalized, "material": {}, "reason": "invalid_socket"}
	var socket: Dictionary = sockets[socket_index]
	var material_id: String = _get_socket_material_id(socket)
	if material_id.is_empty():
		return {"ok": false, "item": normalized, "material": {}, "reason": "socket_empty"}
	var material: Dictionary = Materials.make_material(material_id, int(socket.get("level", 1)), str(socket.get("rarity", "")))
	sockets[socket_index]["material_id"] = null
	sockets[socket_index]["material_name"] = ""
	sockets[socket_index]["level"] = 0
	sockets[socket_index]["rarity"] = ""
	return {"ok": true, "item": normalized, "material": material, "reason": "unsocketed"}

static func get_socketed_bonus(item: Dictionary) -> Dictionary:
	var totals: Dictionary = {}
	var sockets: Array = item.get("sockets", [])
	for raw_socket: Variant in sockets:
		if not (raw_socket is Dictionary):
			continue
		var socket: Dictionary = raw_socket
		var material_id: String = _get_socket_material_id(socket)
		if material_id.is_empty():
			continue
		var material: Dictionary = Materials.make_material(material_id, int(socket.get("level", 1)), str(socket.get("rarity", "")))
		var bonus: Dictionary = Materials.get_material_bonus(material)
		for raw_stat: Variant in bonus.keys():
			var stat_id: String = str(raw_stat)
			totals[stat_id] = float(totals.get(stat_id, 0.0)) + float(bonus[raw_stat])
	return totals

static func get_socket_display(item: Dictionary, socket_index: int) -> Dictionary:
	var sockets: Array = item.get("sockets", [])
	if socket_index < 0 or socket_index >= sockets.size():
		return {}
	return (sockets[socket_index] as Dictionary).duplicate(true)

static func get_socket_label(socket_type: String) -> String:
	match socket_type:
		Materials.SOCKET_DECORATIVE:
			return "裝飾"
		Materials.SOCKET_ENGRAVING:
			return "雕刻"
		Materials.SOCKET_RUNE:
			return "銘文"
		_:
			return socket_type

static func _get_socket_material_id(socket: Dictionary) -> String:
	var value: Variant = socket.get("material_id", socket.get("id", socket.get("item_id", null)))
	if value == null:
		return ""
	var text: String = str(value).strip_edges()
	return "" if text.is_empty() or text == "Null" else text
