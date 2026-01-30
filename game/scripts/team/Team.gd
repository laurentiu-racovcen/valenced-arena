extends Node
class_name Team

@export var teamName: String = "Team"
var id
var forward_dir: Vector2 = Vector2.RIGHT
var members: Array[Agent] = []
@onready var comms: CommsManager = $Comms

func _ready():
	# Ensure id is initialized before using it.
	id = get_team_id()
	forward_dir = Vector2.RIGHT if id == 0 else Vector2.LEFT
	# Apply communication mode from settings
	_apply_communication_mode()

const ROLE_ORDER = [
	Agent.Role.LEADER,
	Agent.Role.TANK,
	Agent.Role.SUPPORT,
	Agent.Role.ADVANCE
]

func add_member(agent: Agent, setup: int) -> void:
	members.append(agent)
	agent.team = self
	# Keep id/forward_dir in sync even if members are added after _ready().
	id = get_team_id()
	forward_dir = Vector2.RIGHT if id == 0 else Vector2.LEFT

	if agent.id == "":
		agent.id = agent.name

	if setup == 0:
		_assign_roles()
	
func _assign_roles():
	# First 3 agents get: Leader, Tank, Support
	for i in range(members.size()):
		if i < ROLE_ORDER.size():
			members[i].set_role(ROLE_ORDER[i])
		else:
			members[i].set_role(Agent.Role.ADVANCE)   # SCUT


func get_team_id() -> int:
	if name.ends_with("A"):
		return 0
	elif name.ends_with("B"):
		return 1
	return 0

func get_leader() -> Agent:
	for member in members:
		if member.role == Agent.Role.LEADER and member.is_alive():
			return member
	return null

func _ensure_leader_exists() -> void:
	# When the current leader dies, some roles (Tank/Advance) would stop moving.
	# Promote a surviving member to leader so formation/advance logic continues.
	
	# SKIP PROMOTIONS in KOTH and CTF modes - agents respawn with original roles
	# Promotions would cause wrong roles when respawning
	var game_mode = MatchConfig.game_mode if MatchConfig else Enums.GameMode.SURVIVAL
	if game_mode == Enums.GameMode.KOTH or game_mode == Enums.GameMode.CTF:
		return  # Don't promote - agents will respawn with their original role
	
	if get_leader() != null:
		return

	var candidate: Agent = null
	var preferred_roles := [Agent.Role.TANK, Agent.Role.SUPPORT, Agent.Role.ADVANCE]
	for r in preferred_roles:
		for m in members:
			if m != null and m.is_alive() and m.role == r:
				candidate = m
				break
		if candidate != null:
			break

	if candidate == null:
		for m in members:
			if m != null and m.is_alive():
				candidate = m
				break

	if candidate != null:
		var old_role := candidate.role
		candidate.set_role(Agent.Role.LEADER)
		print("[Team] %s promoted %s -> LEADER" % [teamName, Agent.Role.keys()[old_role]])
	
func remove_member(agent: Agent):
	if members.has(agent):
		members.erase(agent)
	call_deferred("_on_team_members_changed")

func _on_team_members_changed() -> void:
	_ensure_leader_exists()

## Apply communication mode from settings
func _apply_communication_mode() -> void:
	var enabled_index = SettingsManager.get_comms_enabled_index()
	var type_index = SettingsManager.get_comm_type_index()
	
	var mode_type: CommunicationMode.Type
	var params: Dictionary = {}
	
	match enabled_index:
		0:  # Full communication
			mode_type = CommunicationMode.Type.UNLIMITED
		1:  # Partial - use selected type
			match type_index:
				0:  # LIMITED_DISTANCE
					mode_type = CommunicationMode.Type.LIMITED_DISTANCE
					params["max_distance"] = 300.0
				1:  # LIMITED_TIME
					mode_type = CommunicationMode.Type.LIMITED_TIME
					params["cooldown"] = 1.0
				2:  # HUB_TOPOLOGY
					mode_type = CommunicationMode.Type.HUB_TOPOLOGY
				3:  # RING_TOPOLOGY
					mode_type = CommunicationMode.Type.RING_TOPOLOGY
				4:  # NEAREST_NEIGHBORS
					mode_type = CommunicationMode.Type.NEAREST_NEIGHBORS
					params["neighbor_count"] = 2
				_:
					mode_type = CommunicationMode.Type.LIMITED_DISTANCE
					params["max_distance"] = 300.0
		2:  # No communication
			mode_type = CommunicationMode.Type.NONE
		_:
			mode_type = CommunicationMode.Type.UNLIMITED
	
	var comm_mode = CommunicationMode.new(mode_type, params)
	comms.set_mode(comm_mode)
	print("[Team %s] Communication mode set to: %s" % [teamName, comm_mode])
