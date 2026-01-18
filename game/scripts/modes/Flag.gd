extends Area2D
class_name Flag

## Flag States
enum State { AT_BASE, CARRIED, DROPPED }

## Current state
var state: State = State.AT_BASE

## Team this flag belongs to (0 = Blue, 1 = Red)
@export var team_id: int = 0

## The agent carrying this flag (null if not carried)
var carrier: Agent = null

## Original spawn position
var base_position: Vector2 = Vector2.ZERO

## Timer for auto-return when dropped
var drop_timer: float = 0.0
const RETURN_TIME: float = 15.0

## Visual offset when carried
const CARRY_OFFSET: Vector2 = Vector2(0, -30)

## Speed penalty for carrier
const CARRIER_SPEED_MULT: float = 0.75

## Signals
signal picked_up(flag: Flag, by_agent: Agent)
signal dropped(flag: Flag, position: Vector2)
signal returned_to_base(flag: Flag)
signal delivered(flag: Flag, by_agent: Agent)

## Team colors
const TEAM_COLORS := {
	0: Color(0.2, 0.4, 1.0, 1.0),  # Blue
	1: Color(1.0, 0.2, 0.2, 1.0)   # Red
}

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	base_position = global_position
	add_to_group("flags")
	
	# Connect collision signals
	body_entered.connect(_on_body_entered)
	
	# Set team color
	_update_visual()
	
	# Set collision layer/mask for pickup detection
	# Agents are on layer 1 by default (CharacterBody2D default)
	collision_layer = 0
	collision_mask = 1  # Detect agents on layer 1

func _process(delta: float) -> void:
	match state:
		State.CARRIED:
			_update_carried_position()
		State.DROPPED:
			drop_timer -= delta
			if drop_timer <= 0:
				return_to_base()
	
	# Update visual effects each frame
	_update_visual()

func _update_carried_position() -> void:
	if carrier and is_instance_valid(carrier):
		global_position = carrier.global_position + CARRY_OFFSET
	else:
		# Carrier was destroyed
		drop(global_position)

func _update_visual() -> void:
	if sprite:
		sprite.modulate = TEAM_COLORS.get(team_id, Color.WHITE)
	
	# Pulsing effect when dropped
	if state == State.DROPPED:
		var pulse = abs(sin(Time.get_ticks_msec() * 0.005))
		if sprite:
			sprite.modulate.a = 0.5 + pulse * 0.5
			sprite.scale = Vector2.ONE
	
	# Glowing effect when carried (makes carrier more visible)
	elif state == State.CARRIED:
		var glow = abs(sin(Time.get_ticks_msec() * 0.008))
		if sprite:
			sprite.modulate.a = 0.8 + glow * 0.2
			sprite.scale = Vector2.ONE * (1.0 + glow * 0.2)  # Pulse scale 1.0 to 1.2
	else:
		if sprite:
			sprite.scale = Vector2.ONE

func _on_body_entered(body: Node2D) -> void:
	if not body is Agent:
		return
	
	var agent := body as Agent
	if not agent.is_alive():
		return
	
	var agent_team: int = agent.team.get_team_id() if agent.team else -1
	
	match state:
		State.AT_BASE:
			# Only enemies can pick up the flag
			if agent_team != team_id:
				pickup(agent)
		State.DROPPED:
			if agent_team == team_id:
				# Friendly agent returns the flag
				return_to_base()
			else:
				# Enemy agent picks up the flag
				pickup(agent)
		State.CARRIED:
			# Check if carrier reached their own base (delivery)
			pass  # Delivery handled by FlagZone

func pickup(agent: Agent) -> void:
	if state == State.CARRIED:
		return
	
	state = State.CARRIED
	carrier = agent
	drop_timer = 0.0
	
	# Apply speed penalty to carrier
	if carrier.has_meta("original_speed_mult"):
		pass  # Already has the flag
	else:
		carrier.set_meta("original_speed_mult", 1.0)
		carrier.set_meta("carrying_flag", true)
	
	picked_up.emit(self, agent)
	print("[CTF] %s picked up %s flag!" % [agent.name, "Blue" if team_id == 0 else "Red"])

func drop(position: Vector2) -> void:
	if state != State.CARRIED:
		return
	
	# Remove speed penalty from old carrier
	if carrier and is_instance_valid(carrier):
		carrier.remove_meta("carrying_flag")
		carrier.remove_meta("original_speed_mult")
	
	state = State.DROPPED
	global_position = position
	carrier = null
	drop_timer = RETURN_TIME
	
	dropped.emit(self, position)
	print("[CTF] %s flag dropped at %s (returning in %.0fs)" % [
		"Blue" if team_id == 0 else "Red", str(position), RETURN_TIME
	])

func return_to_base() -> void:
	# Remove speed penalty from carrier if still carried
	if carrier and is_instance_valid(carrier):
		carrier.remove_meta("carrying_flag")
		carrier.remove_meta("original_speed_mult")
	
	state = State.AT_BASE
	global_position = base_position
	carrier = null
	drop_timer = 0.0
	
	returned_to_base.emit(self)
	print("[CTF] %s flag returned to base!" % ["Blue" if team_id == 0 else "Red"])

func deliver(delivering_agent: Agent) -> void:
	if state != State.CARRIED or carrier != delivering_agent:
		return
	
	# Remove speed penalty
	if carrier and is_instance_valid(carrier):
		carrier.remove_meta("carrying_flag")
		carrier.remove_meta("original_speed_mult")
	
	delivered.emit(self, delivering_agent)
	print("[CTF] %s captured the %s flag!" % [
		delivering_agent.name, "Blue" if team_id == 0 else "Red"
	])
	
	# Return flag to its base after capture
	return_to_base()

## Get the opposite team's ID
func get_enemy_team() -> int:
	return 1 if team_id == 0 else 0

## Check if a specific agent is carrying this flag
func is_carried_by(agent: Agent) -> bool:
	return state == State.CARRIED and carrier == agent

## Force drop (used when carrier dies)
func on_carrier_died() -> void:
	if state == State.CARRIED and carrier:
		drop(carrier.global_position)
