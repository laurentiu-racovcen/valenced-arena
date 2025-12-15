extends Node2D
class_name GameMap

var time_left: float

@export var survival_map: PackedScene
@export var koth_map: PackedScene
@export var ctf_map: PackedScene

# Obstacles in scenes often default to collision layer 1.
# Use both layer 1 and layer 2 so raycasts work even if map collisions
# haven't been moved to a dedicated "obstacles" layer yet.
const OBSTACLE_MASK := (1 << 0) | (1 << 1)

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
	var space := get_world_2d().direct_space_state
	var params := PhysicsRayQueryParameters2D.create(a, b)
	params.collision_mask = OBSTACLE_MASK

	# Godot expects RIDs in exclude; callers sometimes pass Nodes.
	# Convert what we can and also ignore any Agent bodies hit by the ray
	# (agents often share collision layer 1 with map obstacles by default).
	var exclude_rids: Array[RID] = []
	for item in exclude:
		if item is RID:
			exclude_rids.append(item)
		elif item is CollisionObject2D:
			exclude_rids.append((item as CollisionObject2D).get_rid())
	params.exclude = exclude_rids

	# If the ray hits an agent first, ignore it and continue the ray.
	# This prevents agents from "blocking" LOS when we only care about map obstacles.
	for _i in range(8):
		var hit: Dictionary = space.intersect_ray(params)
		if hit.is_empty():
			return true
		var collider: Object = hit.get("collider")
		if collider != null and collider is Node and (collider as Node).is_in_group("agents"):
			var rid: RID = hit.get("rid", RID())
			exclude_rids.append(rid)
			params.exclude = exclude_rids
			continue
		return false

	return false

func is_position_blocked(pos: Vector2) -> bool:
	var p := PhysicsPointQueryParameters2D.new()
	p.position = pos
	p.collision_mask = OBSTACLE_MASK
	p.collide_with_bodies = true
	p.collide_with_areas = false
	var hits := get_world_2d().direct_space_state.intersect_point(p, 1)
	return not hits.is_empty()

func get_roam_point(team_id: int) -> Vector2:
	# Fallback if map isn't ready yet
	if current_map == null:
		return global_position

	# If you don't have a play rect anymore, start with something simple:
	# pick points around the map origin within some radius.
	# (Better: use markers or a bounds node in BaseMap.)
	var center := (current_map as Node2D).global_position
	var radius := 1200.0

	# If we have a nav map, always clamp roam points to it so we don't
	# generate off-map / off-nav targets.
	var nav_map := RID()
	var base_map := current_map as BaseMap
	if base_map and base_map.nav_region:
		nav_map = base_map.nav_region.get_navigation_map()

	for _i in range(40):
		var p := center + Vector2.RIGHT.rotated(randf() * TAU) * randf() * radius
		if nav_map != RID():
			p = NavigationServer2D.map_get_closest_point(nav_map, p)
		if not is_position_blocked(p):
			return p

	if nav_map != RID():
		return NavigationServer2D.map_get_closest_point(nav_map, center)
	return center
