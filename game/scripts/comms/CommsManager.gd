extends Node
class_name CommsManager

## Signals pentru monitoring
signal message_sent(message: Message)
signal message_received(receiver_id: String, message: Message)
signal message_blocked(message: Message, reason: String)

## Registry agenți
var registered_agents: Dictionary = {}  # agent_id -> Agent node

## Mod de comunicare curent
var current_mode: CommunicationMode = null

## Tracking pentru restricții
var last_message_times: Dictionary = {}  # agent_id -> timestamp
var message_log: Array[Message] = []

## Statistics
var stats = {
	"total_sent": 0,
	"total_blocked": 0,
	"blocked_by_distance": 0,
	"blocked_by_time": 0,
	"blocked_by_topology": 0
}

func _ready():
	# Default: unlimited communication
	current_mode = CommunicationMode.new(CommunicationMode.Type.UNLIMITED)
	print("[CommsManager] Initialized with mode: ", current_mode)

## === AGENT REGISTRATION === ##

func register_agent(id: String, agent_node: Node) -> void:
	if registered_agents.has(id):
		push_warning("[CommsManager] Agent %s already registered" % id)
	registered_agents[id] = agent_node
	last_message_times[id] = 0.0
	print("[CommsManager] Registered agent: %s" % id)

func unregister_agent(id: String) -> void:
	if registered_agents.has(id):
		registered_agents.erase(id)
		last_message_times.erase(id)

## === MESSAGE SENDING === ##

func send_message(message: Message) -> bool:
	# Validare mesaj
	var validation = message.validate()
	if not validation.valid:
		push_error("[CommsManager] Invalid message: %s" % validation.error)
		return false
	
	# Log
	message_log.append(message)
	stats.total_sent += 1
	message_sent.emit(message)
	
	# Determine destinatarii efectivi
	var effective_targets = _resolve_targets(message)
	
	# Trimite la fiecare target
	var success = false
	for target_id in effective_targets:
		var can_send = can_send_message(message, target_id)
		
		if can_send.can_send:
			_deliver_message(target_id, message)
			success = true
		else:
			stats.total_blocked += 1
			_increment_block_stat(can_send.reason)
			message_blocked.emit(message, can_send.reason)
	
	# Update last message time
	last_message_times[message.sender] = Time.get_ticks_msec() / 1000.0
	
	return success

func _resolve_targets(message: Message) -> Array[String]:
	var resolved: Array[String] = []
	
	for target in message.targets:
		if target == "*":
			# Broadcast la toți înafară de sender
			for agent_id in registered_agents.keys():
				if agent_id != message.sender:
					resolved.append(agent_id)
			break
		else:
			resolved.append(target)
	
	return resolved

func _deliver_message(target_id: String, message: Message) -> void:
	var agent = registered_agents.get(target_id)
	if not agent:
		return
	
	if agent.has_method("receive_message"):
		agent.receive_message(message)
		message_received.emit(target_id, message)

## === VALIDATION === ##

func can_send_message(message: Message, target_id: String) -> Dictionary:
	if not registered_agents.has(target_id):
		return {"can_send": false, "reason": "target_not_found"}
	
	if not current_mode:
		return {"can_send": true, "reason": ""}
	
	match current_mode.mode_type:
		CommunicationMode.Type.UNLIMITED:
			return {"can_send": true, "reason": ""}
		CommunicationMode.Type.NONE:
			return {"can_send": false, "reason": "no_communication"}
		CommunicationMode.Type.LIMITED_DISTANCE:
			return _check_distance(message.sender, target_id)
		CommunicationMode.Type.LIMITED_TIME:
			return _check_time(message.sender)
		CommunicationMode.Type.HUB_TOPOLOGY:
			return _check_hub_topology(message.sender, target_id)
		CommunicationMode.Type.RING_TOPOLOGY:
			return _check_ring_topology(message.sender, target_id)
		CommunicationMode.Type.NEAREST_NEIGHBORS:
			return _check_nearest_neighbors(message.sender, target_id)
	
	return {"can_send": true, "reason": ""}

func _check_distance(sender_id: String, target_id: String) -> Dictionary:
	var sender = registered_agents.get(sender_id)
	var target = registered_agents.get(target_id)
	
	if not sender or not target:
		return {"can_send": false, "reason": "agent_not_found"}
	
	if not sender.has("global_position") or not target.has("global_position"):
		return {"can_send": false, "reason": "no_position"}
	
	var distance = sender.global_position.distance_to(target.global_position)
	
	if distance > current_mode.max_distance:
		return {"can_send": false, "reason": "distance_exceeded"}
	
	return {"can_send": true, "reason": ""}

func _check_time(sender_id: String) -> Dictionary:
	var current_time = Time.get_ticks_msec() / 1000.0
	var last_time = last_message_times.get(sender_id, 0.0)
	var elapsed = current_time - last_time
	
	if elapsed < current_mode.cooldown:
		return {"can_send": false, "reason": "cooldown_active"}
	
	return {"can_send": true, "reason": ""}

func _check_hub_topology(sender_id: String, target_id: String) -> Dictionary:
	var hub_id = current_mode.hub_agent
	
	# Hub poate trimite la oricine
	if sender_id == hub_id:
		return {"can_send": true, "reason": ""}
	
	# Alții pot trimite doar la hub
	if target_id == hub_id:
		return {"can_send": true, "reason": ""}
	
	return {"can_send": false, "reason": "topology_violation"}

func _check_ring_topology(sender_id: String, target_id: String) -> Dictionary:
	var allowed_target = current_mode.connections.get(sender_id, "")
	
	if allowed_target == target_id:
		return {"can_send": true, "reason": ""}
	
	return {"can_send": false, "reason": "topology_violation"}

func _check_nearest_neighbors(sender_id: String, target_id: String) -> Dictionary:
	var sender = registered_agents.get(sender_id)
	if not sender or not sender.has("global_position"):
		return {"can_send": false, "reason": "no_position"}
	
	var neighbors = _get_nearest_neighbors(sender_id, current_mode.neighbor_count)
	
	if target_id in neighbors:
		return {"can_send": true, "reason": ""}
	
	return {"can_send": false, "reason": "topology_violation"}

func _get_nearest_neighbors(agent_id: String, count: int) -> Array[String]:
	var agent = registered_agents.get(agent_id)
	if not agent or not agent.has("global_position"):
		return []
	
	var distances: Array = []
	
	for other_id in registered_agents.keys():
		if other_id == agent_id:
			continue
		
		var other = registered_agents.get(other_id)
		if not other or not other.has("global_position"):
			continue
		
		var dist = agent.global_position.distance_to(other.global_position)
		distances.append({"id": other_id, "distance": dist})
	
	distances.sort_custom(func(a, b): return a.distance < b.distance)
	
	var result: Array[String] = []
	for i in range(min(count, distances.size())):
		result.append(distances[i].id)
	
	return result

## === MODE MANAGEMENT === ##

func set_mode(mode: CommunicationMode) -> void:
	current_mode = mode
	print("[CommsManager] Mode changed to: %s" % mode)

## === STATISTICS === ##

func get_statistics() -> Dictionary:
	return stats.duplicate()

func _increment_block_stat(reason: String) -> void:
	match reason:
		"distance_exceeded":
			stats.blocked_by_distance += 1
		"cooldown_active":
			stats.blocked_by_time += 1
		"topology_violation":
			stats.blocked_by_topology += 1

## === LEGACY COMPATIBILITY (pentru Support.gd) === ##

var agents: Dictionary:
	get: return registered_agents

func get_help_request() -> Agent:
	# Find agent cu HP cel mai mic care cere ajutor
	for msg in message_log:
		if msg.message_type == Message.Type.ASSIST:
			var sender = registered_agents.get(msg.sender)
			if sender and sender.is_alive():
				return sender
	return null
