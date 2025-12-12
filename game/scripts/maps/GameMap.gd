extends Node2D
class_name GameMap

var time_left: float

@export var survival_map: PackedScene
@export var koth_map: PackedScene
@export var ctf_map: PackedScene

@onready var map_holder: Node = $MapHolder
var current_map: Node = null
signal map_loaded

func _ready():
	load_mode(MatchConfig.game_mode)

func load_mode(mode: Enums.GameMode) -> void:
	print("\nmode = ", mode)
	# Remove previous map (frees its Sprite2D + StaticBody2D + polygons too). [web:61]
	if current_map:
		current_map.queue_free()
		current_map = null

	var chosen: PackedScene = {
		Enums.GameMode.SURVIVAL: survival_map,
		Enums.GameMode.KOTH: koth_map,
		Enums.GameMode.CTF: ctf_map,
	}.get(mode)

	if chosen == null:
		push_error("No map PackedScene set for mode")
		return

	# Instance and attach to the tree. [web:61]
	current_map = chosen.instantiate() as BaseMap
	print("mode =", mode, " type =", typeof(mode))
	map_holder.add_child(current_map)
	map_loaded.emit()

func get_spawn_global(team_id: int, index_in_team: int) -> Vector2:
	if current_map == null:
		print("null spawn")
		push_error("Map not loaded yet")
		return global_position
	print("spawn marker: ", (current_map as BaseMap).get_spawn_global(team_id, index_in_team))
	return (current_map as BaseMap).get_spawn_global(team_id, index_in_team)

func has_line_of_sight(a: Vector2, b: Vector2, exclude: Array = []) -> bool:
	return 0 # TODO

func is_position_blocked(pos: Vector2) -> bool:
	var p := PhysicsPointQueryParameters2D.new()
	p.position = pos
	var hits := get_world_2d().direct_space_state.intersect_point(p, 1)
	return not hits.is_empty()
