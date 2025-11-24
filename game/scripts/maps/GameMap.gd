extends Node2D
class_name GameMap

@onready var obstacles: TileMap = %Obstacles

var time_left: float

func has_line_of_sight(a: Vector2, b: Vector2) -> bool:
	var params := PhysicsRayQueryParameters2D.create(a, b)
	params.collision_mask = obstacles.collision_layer
	var hit := get_world_2d().direct_space_state.intersect_ray(params)
	return hit.is_empty()

func is_position_blocked(pos: Vector2) -> bool:
	var p := PhysicsPointQueryParameters2D.new()
	p.position = pos
	p.collision_mask = obstacles.collision_layer
	var hits := get_world_2d().direct_space_state.intersect_point(p, 1)
	return not hits.is_empty()
