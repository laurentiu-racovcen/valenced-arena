extends Area2D
class_name Bullet

@export var speed: float = 500
var direction: Vector2 = Vector2.ZERO
var damage: int = 10

var traveled_distance: float = 0.0
@export var max_distance: float = 2000.0

var shooter: Agent = null

func _ready() -> void:
	# Conectează semnalul pentru coliziuni
	body_entered.connect(_on_body_entered)
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return

	# Prevent tunneling through thin obstacles:
	# raycast from current position to next position.
	var from_pos := global_position
	var step := direction.normalized() * speed * delta
	var to_pos := from_pos + step

	var params := PhysicsRayQueryParameters2D.create(from_pos, to_pos)
	params.collision_mask = collision_mask
	params.collide_with_bodies = true
	params.collide_with_areas = false

	var exclude_rids: Array[RID] = [get_rid()]
	if shooter != null:
		exclude_rids.append(shooter.get_rid())
	params.exclude = exclude_rids

	# If we hit a teammate first, ignore them and continue the ray (prevents friendly-fire).
	var space := get_world_2d().direct_space_state
	for _i in range(8):
		var hit: Dictionary = space.intersect_ray(params)
		if hit.is_empty():
			break
		var collider: Object = hit.get("collider")
		if collider != null and collider is Agent and shooter != null:
			var a := collider as Agent
			if a.team != null and shooter.team != null and a.team == shooter.team:
				# Ignore teammate and continue checking the rest of the segment.
				var rid: RID = hit.get("rid", RID())
				if rid != RID():
					exclude_rids.append(rid)
					params.exclude = exclude_rids
					continue
		# Hit something we should stop on (enemy agent, wall, etc.)
		if collider != null and collider is Agent:
			(collider as Agent).take_damage(damage, shooter)
		queue_free()
		return

	global_position = to_pos
	traveled_distance += step.length()
	
	if traveled_distance > max_distance:
		queue_free()

func _on_body_entered(body: Node) -> void:
	# Ignoră propriul shooter
	if body == shooter:
		return
	
	if body is Agent:
		# Ignore teammates (no friendly fire)
		if shooter != null and (body as Agent).team != null and shooter.team != null and (body as Agent).team == shooter.team:
			return
		(body as Agent).take_damage(damage, shooter)
		queue_free()
		return

	# Hit something else (wall, etc.)
	queue_free()
