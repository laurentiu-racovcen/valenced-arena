extends RefCounted
class_name Message

## Tipuri de mesaje conform documentației
enum Type {
	STATUS,      ## Raportare stare agent (hp, ammo, position, state)
	MOVE,        ## Anunțare mișcare (x, y)
	ASSIST,      ## Cerere ajutor (x, y, urgency 1-5)
	FOCUS,       ## Comandă atac focalizat (target_id, x, y, priority 1-5)
	RETREAT,     ## Anunțare retragere (x, y, reason)
	OBJECTIVE    ## Alocare obiectiv (objective_type, target_position, eta)
}

## Proprietățile mesajului
var timestamp: float
var sender: String
var targets: Array[String]
var message_type: Type
var content: Dictionary

## Constructor
func _init(
	p_timestamp: float,
	p_sender: String,
	p_targets: Array[String],
	p_message_type: Type,
	p_content: Dictionary
):
	timestamp = p_timestamp
	sender = p_sender
	targets = p_targets
	message_type = p_message_type
	content = p_content

## Validare mesaj
func validate() -> Dictionary:
	match message_type:
		Type.STATUS:
			return _validate_status()
		Type.MOVE:
			return _validate_move()
		Type.ASSIST:
			return _validate_assist()
		Type.FOCUS:
			return _validate_focus()
		Type.RETREAT:
			return _validate_retreat()
		Type.OBJECTIVE:
			return _validate_objective()
	return {"valid": false, "error": "Unknown message type"}

func _validate_status() -> Dictionary:
	var required = ["hp", "max_hp", "ammo", "position", "state"]
	for field in required:
		if not content.has(field):
			return {"valid": false, "error": "Missing field: " + field}
	return {"valid": true}

func _validate_move() -> Dictionary:
	if not content.has("x") or not content.has("y"):
		return {"valid": false, "error": "Missing x or y"}
	return {"valid": true}

func _validate_assist() -> Dictionary:
	var required = ["x", "y", "urgency"]
	for field in required:
		if not content.has(field):
			return {"valid": false, "error": "Missing field: " + field}
	var urgency = content.urgency
	if urgency < 1 or urgency > 5:
		return {"valid": false, "error": "Urgency must be 1-5"}
	return {"valid": true}

func _validate_focus() -> Dictionary:
	var required = ["target_id", "x", "y", "priority"]
	for field in required:
		if not content.has(field):
			return {"valid": false, "error": "Missing field: " + field}
	var priority = content.priority
	if priority < 1 or priority > 5:
		return {"valid": false, "error": "Priority must be 1-5"}
	return {"valid": true}

func _validate_retreat() -> Dictionary:
	var required = ["x", "y", "reason"]
	for field in required:
		if not content.has(field):
			return {"valid": false, "error": "Missing field: " + field}
	return {"valid": true}

func _validate_objective() -> Dictionary:
	var required = ["objective_type", "target_position", "eta"]
	for field in required:
		if not content.has(field):
			return {"valid": false, "error": "Missing field: " + field}
	return {"valid": true}

## Conversie la Dictionary pentru debug/logging
func to_dict() -> Dictionary:
	return {
		"timestamp": timestamp,
		"sender": sender,
		"targets": targets,
		"message_type": Type.keys()[message_type],
		"content": content
	}

## Helper pentru debugging
func _to_string() -> String:
	return "[Message %s from %s to %s]" % [
		Type.keys()[message_type],
		sender,
		", ".join(targets) if not targets.is_empty() else "none"
	]
