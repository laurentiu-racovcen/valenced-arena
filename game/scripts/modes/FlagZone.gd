extends Area2D
class_name FlagZone

## Zone Types
enum ZoneType { FLAG_SPAWN, CAPTURE_ZONE }

## Team this zone belongs to (0 = Blue, 1 = Red)
@export var team_id: int = 0

## Type of zone
@export var zone_type: ZoneType = ZoneType.FLAG_SPAWN

## Visual settings
@export var zone_radius: float = 120.0
@export var show_visual: bool = true

## Team colors
const TEAM_COLORS := {
	0: Color(0.2, 0.4, 1.0, 0.3),  # Blue
	1: Color(1.0, 0.2, 0.2, 0.3)   # Red
}

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var visual: Sprite2D = $Visual

func _ready() -> void:
	# Set up the zone
	_setup_collision()
	_setup_visual()
	
	# Add to appropriate group
	if zone_type == ZoneType.FLAG_SPAWN:
		add_to_group("flag_spawns")
	else:
		add_to_group("capture_zones")
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Set collision properties
	collision_layer = 0
	collision_mask = 2  # Agents layer

func _setup_collision() -> void:
	if collision and collision.shape is CircleShape2D:
		(collision.shape as CircleShape2D).radius = zone_radius

func _setup_visual() -> void:
	if visual and show_visual:
		visual.modulate = TEAM_COLORS.get(team_id, Color.WHITE)
		visual.scale = Vector2(zone_radius / 50.0, zone_radius / 50.0)
	elif visual:
		visual.visible = false

func _on_body_entered(body: Node2D) -> void:
	if not body is Agent:
		return
	
	var agent := body as Agent
	if not agent.is_alive():
		return
	
	# Emit signal for game mode to handle
	if zone_type == ZoneType.CAPTURE_ZONE:
		# Check if agent can capture here
		pass

func _on_body_exited(body: Node2D) -> void:
	pass

## Check if a position is inside this zone
func contains_position(pos: Vector2) -> bool:
	return global_position.distance_to(pos) <= zone_radius

## Get the team name
func get_team_name() -> String:
	return "Blue" if team_id == 0 else "Red"
