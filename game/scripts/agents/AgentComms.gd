extends Node
class_name AgentComms

var agent: Agent
var comms_manager: CommsManager

## Queue mesaje primite
var received_messages: Array[Message] = []

# Rate limiting (prevents output spam + comms spam when taking sustained damage)
@export var assist_broadcast_cooldown: float = 1.0
var _last_assist_sent_at: float = -999.0
var _last_assist_urgency: int = 0

func _ready():
	print("[AgentComms] _ready() called for agent: ", get_parent().name if get_parent() else "no parent")
	
	agent = get_parent() as Agent
	if not agent:
		push_error("[AgentComms] Parent is not an Agent!")
		return
	
	print("[AgentComms] Waiting for agent initialization...")
	# Așteaptă ca agentul să fie complet inițializat (team + id)
	await get_tree().process_frame
	
	print("[AgentComms] Agent team: ", agent.team, " - has Comms: ", agent.team.has_node("Comms") if agent.team else false)
	
	# Găsește CommsManager în team
	if agent.team and agent.team.has_node("Comms"):
		comms_manager = agent.team.get_node("Comms")
		
		# Verifică că agent.id e setat
		if agent.id != "":
			comms_manager.register_agent(agent.id, agent)
			print("[AgentComms] %s registered to team comms" % agent.id)
		else:
			push_warning("[AgentComms] Agent ID empty, using name: %s" % agent.name)
			comms_manager.register_agent(agent.name, agent)
	else:
		push_error("[AgentComms] No team or Comms node found!")

## === MESSAGE SENDING === ##

func send_status(targets: Array[String] = ["*"]) -> bool:
	if not comms_manager:
		return false
	
	var message = Message.new(
		Time.get_ticks_msec() / 1000.0,
		agent.id,
		targets,
		Message.Type.STATUS,
		{
			"hp": agent.hp,
			"max_hp": agent.max_hp,
			"ammo": agent.ammo,
			"position": {
				"x": agent.global_position.x,
				"y": agent.global_position.y
			},
			"state": _get_agent_state()
		}
	)
	
	return comms_manager.send_message(message)

func send_move_intent(target_position: Vector2, targets: Array[String] = ["*"]) -> bool:
	if not comms_manager:
		return false
	
	var message = Message.new(
		Time.get_ticks_msec() / 1000.0,
		agent.id,
		targets,
		Message.Type.MOVE,
		{
			"x": target_position.x,
			"y": target_position.y
		}
	)
	
	return comms_manager.send_message(message)

func request_assist(position: Vector2, urgency: int = 3, targets: Array[String] = ["*"]) -> bool:
	if not comms_manager:
		push_warning("[AgentComms] Cannot request assist - no comms_manager!")
		return false
	
	urgency = clampi(urgency, 1, 5)

	var now: float = Time.get_ticks_msec() / 1000.0
	var can_send: bool = (now - _last_assist_sent_at) >= assist_broadcast_cooldown or urgency > _last_assist_urgency
	if not can_send:
		return false
	_last_assist_sent_at = now
	_last_assist_urgency = urgency
	
	var message = Message.new(
		now,
		agent.id if agent.id != "" else agent.name,
		targets,
		Message.Type.ASSIST,
		{
			"x": position.x,
			"y": position.y,
			"urgency": urgency
		}
	)
	
	# Print only when AI debug is enabled to avoid output overflow.
	if agent != null and agent.debug_ai:
		print("[AgentComms] Sending ASSIST message from %s" % message.sender)
	return comms_manager.send_message(message)

func broadcast_focus_target(target_agent_id: String, target_position: Vector2, priority: int = 3, targets: Array[String] = ["*"]) -> bool:
	if not comms_manager:
		return false
	
	priority = clampi(priority, 1, 5)
	
	var message = Message.new(
		Time.get_ticks_msec() / 1000.0,
		agent.id if agent != null and agent.id != "" else (agent.name if agent != null else ""),
		targets,
		Message.Type.FOCUS,
		{
			"target_id": target_agent_id,
			"x": target_position.x,
			"y": target_position.y,
			"priority": priority
		}
	)
	
	return comms_manager.send_message(message)

func announce_retreat(retreat_position: Vector2, reason: String = "low_hp", targets: Array[String] = ["*"]) -> bool:
	if not comms_manager:
		return false
	
	var message = Message.new(
		Time.get_ticks_msec() / 1000.0,
		agent.id,
		targets,
		Message.Type.RETREAT,
		{
			"x": retreat_position.x,
			"y": retreat_position.y,
			"reason": reason
		}
	)
	
	return comms_manager.send_message(message)

## === MESSAGE RECEIVING === ##

func receive_message(message: Message) -> void:
	received_messages.append(message)
	_handle_message(message)

func _handle_message(message: Message) -> void:
	match message.message_type:
		Message.Type.STATUS:
			if agent.has_method("on_teammate_status"):
				agent.on_teammate_status(message)
		Message.Type.MOVE:
			if agent.has_method("on_teammate_move"):
				agent.on_teammate_move(message)
		Message.Type.ASSIST:
			if agent.has_method("on_assist_request"):
				agent.on_assist_request(message)
		Message.Type.FOCUS:
			if agent.has_method("on_focus_target"):
				agent.on_focus_target(message)
		Message.Type.RETREAT:
			if agent.has_method("on_teammate_retreat"):
				agent.on_teammate_retreat(message)
		Message.Type.OBJECTIVE:
			if agent.has_method("on_objective_assigned"):
				agent.on_objective_assigned(message)

## === UTILITY === ##

func _get_agent_state() -> String:
	if not agent.is_alive():
		return "dead"
	
	if agent.hp < agent.max_hp * 0.3:
		return "critical"
	elif agent.hp < agent.max_hp * 0.5:
		return "damaged"
	
	if agent.ammo == 0:
		return "no_ammo"
	elif agent.ammo < agent.ammo_max * 0.3:
		return "low_ammo"
	
	var enemies = agent.perception.get_visible_enemies() if agent.perception else []
	if enemies.size() > 0:
		return "combat"
	
	return "idle"

func get_messages_of_type(msg_type: Message.Type) -> Array[Message]:
	var filtered: Array[Message] = []
	for msg in received_messages:
		if msg.message_type == msg_type:
			filtered.append(msg)
	return filtered

func has_messages_of_type(msg_type: Message.Type) -> bool:
	for msg in received_messages:
		if msg.message_type == msg_type:
			return true
	return false

func clear_old_messages(max_age: float = 10.0) -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	received_messages = received_messages.filter(
		func(msg): return (current_time - msg.timestamp) < max_age
	)
