extends Node2D
class_name GameMap

@onready var obstacles: TileMap = $Obstacles  # doar ca referință, nu-i mai citim layerele

const OBSTACLE_MASK := 1 << 1  # Layer 2, același pe care l-ai pus în TileSet

var time_left: float

func get_play_rect() -> Rect2:
	var sprite := $Map as Sprite2D
	var tex := sprite.texture
	if tex == null:
		return Rect2(Vector2.ZERO, Vector2(1920, 1080)) # fallback

	var size := Vector2(tex.get_width(), tex.get_height()) * sprite.global_scale
	return Rect2(sprite.global_position - size * 0.5, size)

func get_team_spawn_center(team_id: int, padding := 180.0) -> Vector2:
	var r := get_play_rect()
	var x := (r.position.x + padding) if team_id == 0 else (r.end.x - padding)
	return Vector2(x, r.position.y + r.size.y * 0.5)

func has_line_of_sight(a: Vector2, b: Vector2, exclude: Array = []) -> bool:
	var params := PhysicsRayQueryParameters2D.create(a, b)
	params.collision_mask = OBSTACLE_MASK      # lovim DOAR obstacolele
	params.exclude = exclude                   # excludem agentul și ținta

	var hit := get_world_2d().direct_space_state.intersect_ray(params)
	return hit.is_empty()  # true = nu e perete între ei

func is_position_blocked(pos: Vector2) -> bool:
	var p := PhysicsPointQueryParameters2D.new()
	p.position = pos
	p.collision_mask = obstacles.collision_layer
	var hits := get_world_2d().direct_space_state.intersect_point(p, 1)
	return not hits.is_empty()
