extends Node2D
class_name BaseMap

@onready var map_sprite: Sprite2D = $MapTexture
@onready var map_body: StaticBody2D = $Collisions
@onready var spawns: Node = $Spawns

var nav_region: NavigationRegion2D
signal navigation_ready

func _ready() -> void:
	assert(map_sprite != null)
	assert(map_body != null)
	
	# Find manually created NavigationRegion2D in the scene
	_find_manual_navigation()
	
	# Navigation is now set up manually in the editor
	# Uncomment the line below if you want automatic generation instead:
	# call_deferred("_build_navigation")

func _find_manual_navigation() -> void:
	# Look for a NavigationRegion2D that was manually added in the editor
	var found_nav = find_child("NavigationRegion2D", true, false) as NavigationRegion2D
	if found_nav:
		nav_region = found_nav
		nav_region.add_to_group("navigation")
		print("[BaseMap] Found manually created NavigationRegion2D: %s" % nav_region.name)
		
		# Ensure navigation mesh is baked
		if nav_region.navigation_polygon:
			# Check if already baked
			if nav_region.navigation_polygon.get_polygon_count() > 0:
				call_deferred("_signal_navigation_ready")
			else:
				# Need to bake it
				nav_region.bake_navigation_polygon()
				# Wait a bit for baking to complete, then check
				await get_tree().create_timer(0.2).timeout
				call_deferred("_check_manual_navigation_baked")
		else:
			push_warning("[BaseMap] NavigationRegion2D found but has no NavigationPolygon resource assigned!")
	else:
		push_warning("[BaseMap] No NavigationRegion2D found! Make sure you added one manually in the editor.")

func _check_manual_navigation_baked() -> void:
	if nav_region and nav_region.navigation_polygon:
		var polygon_count = nav_region.navigation_polygon.get_polygon_count()
		if polygon_count > 0:
			_signal_navigation_ready()
		else:
			# Still not baked, wait a bit more
			await get_tree().create_timer(0.1).timeout
			call_deferred("_check_manual_navigation_baked")

func _signal_navigation_ready() -> void:
	# Signal that navigation is ready for agents
	navigation_ready.emit()
	var polygon_count = nav_region.navigation_polygon.get_polygon_count() if nav_region and nav_region.navigation_polygon else 0
	print("[BaseMap PATHFINDING] Manual navigation region ready! Map: %s | Nav polygons: %d" % [name, polygon_count])

func _build_navigation() -> void:
	# 1) Create a region (no manual editor setup needed)
	nav_region = NavigationRegion2D.new()
	nav_region.name = "NavigationRegion2D"
	add_child(nav_region)

	# 2) Create navigation polygon resource
	var nav := NavigationPolygon.new()

	# 3) Outer boundary (MUST exist; choose one that matches your playable area)
	# Example: from texture size, assuming sprite centered at (0,0)
	var tex := map_sprite.texture
	if tex == null:
		push_error("MapTexture has no texture; cannot derive bounds.")
		return

	var size: Vector2 = tex.get_size() * map_sprite.scale
	var half := size * 0.5
	var outer := PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2( half.x, -half.y),
		Vector2( half.x,  half.y),
		Vector2(-half.x,  half.y),
	])
	nav.add_outline(outer)

	# 4) Get spawn positions first to identify base exit areas
	var base_exit_areas: Array[Rect2] = []
	if spawns:
		var team0_spawns: Array[Vector2] = []
		var team1_spawns: Array[Vector2] = []
		
		for i in range(4):
			var t0_marker = spawns.get_node_or_null("T0_P%d" % i) as Marker2D
			var t1_marker = spawns.get_node_or_null("T1_P%d" % i) as Marker2D
			
			if t0_marker:
				team0_spawns.append(t0_marker.global_position - global_position)
			if t1_marker:
				team1_spawns.append(t1_marker.global_position - global_position)
		
		# Define exit areas (rectangles where we want to preserve walkability)
		if team0_spawns.size() > 0:
			var blue_center := Vector2.ZERO
			for pos in team0_spawns:
				blue_center += pos
			blue_center /= team0_spawns.size()
			# Exit area for blue team (left side, exits rightward)
			base_exit_areas.append(Rect2(blue_center + Vector2(0, -50), Vector2(200, 100)))
		
		if team1_spawns.size() > 0:
			var red_center := Vector2.ZERO
			for pos in team1_spawns:
				red_center += pos
			red_center /= team1_spawns.size()
			# Exit area for red team (right side, exits leftward)
			base_exit_areas.append(Rect2(red_center + Vector2(-200, -50), Vector2(200, 100)))
	
	# 5) Add all CollisionPolygon2D as hole outlines
	# Shrink them and exclude areas near base exits
	var shrink_margin := 15.0  # Increased margin for better gaps
	
	for poly in map_body.find_children("", "CollisionPolygon2D", true, false):
		var cp := poly as CollisionPolygon2D
		if cp == null or cp.polygon.is_empty():
			continue

		# Convert collider local points to BaseMap local
		var to_map_local := global_transform.affine_inverse() * cp.global_transform
		
		# Calculate polygon bounds to check if it overlaps exit areas
		var poly_bounds := Rect2()
		var first_point := true
		for p in cp.polygon:
			var world_p: Vector2 = to_map_local * p
			if first_point:
				poly_bounds = Rect2(world_p, Vector2.ZERO)
				first_point = false
			else:
				poly_bounds = poly_bounds.expand(world_p)
		
		# Check if this polygon overlaps any base exit area
		var overlaps_exit := false
		for exit_area in base_exit_areas:
			if poly_bounds.intersects(exit_area):
				overlaps_exit = true
				break
		
		# If it overlaps an exit, skip it entirely (don't add as hole)
		if overlaps_exit:
			print("[BaseMap] Skipping collision polygon '%s' near base exit" % cp.name)
			continue

		var hole := PackedVector2Array()
		
		# Calculate center of polygon for shrinking
		var center := Vector2.ZERO
		var points: Array[Vector2] = []
		for p in cp.polygon:
			var world_p: Vector2 = to_map_local * p
			points.append(world_p)
			center += world_p
		if points.size() > 0:
			center /= points.size()
		
		# Shrink polygon inward by moving each point toward center
		for p in points:
			var diff: Vector2 = p - center
			var dist := diff.length()
			if dist > 0.01:  # Avoid division by zero
				var dir: Vector2 = diff / dist  # Normalize manually
				var shrunk_p: Vector2 = p - dir * shrink_margin
				hole.append(shrunk_p)
			else:
				# Point is at center, just add it as-is
				hole.append(p)

		nav.add_outline(hole)
	
	var hole_count = nav.get_outline_count() - 1  # -1 because first outline is outer boundary
	print("[BaseMap] Added %d collision polygons as navigation holes (shrunk by %.1f pixels, %d exit areas protected)" % [
		hole_count, shrink_margin, base_exit_areas.size()
	])

	# 5) Assign navigation polygon to region and bake it (Godot 4 method)
	nav_region.navigation_polygon = nav
	
	# Add to group for easy finding
	nav_region.add_to_group("navigation")
	
	# Bake the navigation polygon (this generates the actual navigation mesh)
	# In Godot 4, baking happens asynchronously
	nav_region.bake_navigation_polygon()
	
	# Wait for baking to complete using call_deferred (since we can't use await here)
	# Check after a few frames
	call_deferred("_check_navigation_baked", nav)

func _check_navigation_baked(nav: NavigationPolygon) -> void:
	# Check if navigation mesh has been baked
	if nav_region and nav_region.navigation_polygon:
		var polygon_count = nav_region.navigation_polygon.get_polygon_count()
		if polygon_count > 0:
			_on_navigation_baked(nav_region.navigation_polygon)
		else:
			# Still not baked, wait a bit more
			await get_tree().create_timer(0.1).timeout
			call_deferred("_check_navigation_baked", nav)


func _on_navigation_baked(nav: NavigationPolygon) -> void:
	# Signal that navigation is ready
	navigation_ready.emit()
	
	var polygon_count = nav.get_polygon_count() if nav else 0
	print("[BaseMap PATHFINDING] Navigation region built! Map: %s | Nav polygons: %d | Outlines: %d | Ready for agents!" % [
		name, polygon_count, nav.get_outline_count()
	])

func get_spawn_global(team_id: int, index_in_team: int) -> Vector2:
	var name := "T%d_P%d" % [team_id, index_in_team]
	var m := spawns.get_node_or_null(name) as Marker2D
	if m == null:
		# (avoid printing m.global_position here; m is null)
		push_error("Missing spawn marker: " + name)
		return global_position
	print("spawn marker: ", m.global_position)
	return m.global_position

func get_team_spawn_center(team_id: int) -> Vector2:
	# Average of the 4 spawn markers for the given team.
	# Useful as a stable "base location" target that is always inside the map.
	if spawns == null:
		return global_position

	var sum := Vector2.ZERO
	var count := 0
	for i in range(4):
		var m := spawns.get_node_or_null("T%d_P%d" % [team_id, i]) as Marker2D
		if m:
			sum += m.global_position
			count += 1

	if count == 0:
		return global_position

	return sum / float(count)

func get_map_center() -> Vector2:
	# Prefer a gameplay-relevant "center": midpoint between both team spawn centers.
	# This avoids using the map node origin (often (0,0)) which may be outside nav.
	var c0 := get_team_spawn_center(0)
	var c1 := get_team_spawn_center(1)
	return (c0 + c1) * 0.5

func get_map_half_extents() -> Vector2:
	# Half-width/half-height of the visible map sprite in world units.
	# Useful for "top/bottom sweep" patrol points.
	if map_sprite == null or map_sprite.texture == null:
		return Vector2(800.0, 450.0) # safe fallback
	return map_sprite.texture.get_size() * map_sprite.scale * 0.5
