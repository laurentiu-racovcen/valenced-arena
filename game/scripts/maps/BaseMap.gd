extends Node2D
class_name BaseMap

@onready var map_sprite: Sprite2D = $MapTexture
@onready var map_body: StaticBody2D = $Collisions
@onready var spawns: Node = $Spawns

func _ready() -> void:
	assert(map_sprite != null)
	assert(map_body != null)

func get_spawn_global(team_id: int, index_in_team: int) -> Vector2:
	var name := "T%d_P%d" % [team_id, index_in_team]
	var m := spawns.get_node_or_null(name) as Marker2D
	if m == null:
		print("null spawn marker: ", m.global_position)
		push_error("Missing spawn marker: " + name)
		return global_position
	print("spawn marker: ", m.global_position)
	return m.global_position
