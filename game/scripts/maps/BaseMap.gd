extends Node2D
class_name BaseMap

@onready var map_sprite: Sprite2D = $MapTexture
@onready var map_body: StaticBody2D = $Collisions
@onready var spawns: Node = $Spawns

var nav_region: NavigationRegion2D

func _ready() -> void:
	assert(map_sprite != null)
	assert(map_body != null)
	
	# Build after transforms are stable.
	call_deferred("_build_navigation")

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

	# 4) Add all CollisionPolygon2D as hole outlines
	for poly in map_body.find_children("", "CollisionPolygon2D", true, false):
		var cp := poly as CollisionPolygon2D
		if cp == null or cp.polygon.is_empty():
			continue

		var hole := PackedVector2Array()
		# Convert collider local points to BaseMap local (nav_region is a child at identity)
		var to_map_local := global_transform.affine_inverse() * cp.global_transform
		for p in cp.polygon:
			hole.append(to_map_local * p)

		nav.add_outline(hole)

	# 5) Generate polygons and assign to the region
	# Note: make_polygons_from_outlines() is deprecated but still commonly used for this outlines workflow.
	nav.make_polygons_from_outlines()
	nav_region.navigation_polygon = nav

func get_spawn_global(team_id: int, index_in_team: int) -> Vector2:
	var name := "T%d_P%d" % [team_id, index_in_team]
	var m := spawns.get_node_or_null(name) as Marker2D
	if m == null:
		print("null spawn marker: ", m.global_position)
		push_error("Missing spawn marker: " + name)
		return global_position
	print("spawn marker: ", m.global_position)
	return m.global_position
