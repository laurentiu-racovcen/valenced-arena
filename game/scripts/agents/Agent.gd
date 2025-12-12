extends CharacterBody2D
class_name Agent

enum Role { LEADER, ADVANCE, TANK, SUPPORT }
var role_logic: Node = null

@export var role: Role = Role.ADVANCE

@export var max_hp: int = 100
@export var move_speed: float = 200.0
@export var damage_per_shot: int = 10
@export var fire_rate: float = 2.0
@export var ammo_max: int = 30
@export var reload_time: float = 2.0
@export var los_range: float = 1700.0
@onready var perception: AgentPerception = $AgentPerception
@onready var visual = $Visual

@onready var gun_pivot = $GunPivot

var move_dir: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.ZERO
@export var body_turn_speed: float = 6.0
@export var gun_turn_speed: float = 10.0
@export var accel := 10.0  # higher = snappier steering

var hp: int
var ammo: int
var id: String = ""
var team
var map: GameMap
var fire_cooldown: float = 0.0

@export var wall_mask: int = 1 << 1     # set to your walls/obstacles layer mask
@export var avoid_probe: float = 60.0   # how far ahead to probe
@export var avoid_angle_step_deg := 15.0
@export var avoid_steps := 8            # tries per side (8*15=120 deg)

var avoid_dir := Vector2.ZERO
var avoid_lock := 0.0
@export var avoid_lock_time := 0.25

var wall_following := false
var wall_follow_dir := Vector2.ZERO

@export var stuck_time_to_unstuck := 0.35
@export var min_progress_px := 2.0
@export var unstuck_duration := 0.45

var _last_pos: Vector2
var _stuck_time := 0.0
var _unstuck_time := 0.0
var _unstuck_dir := Vector2.ZERO

var roam_target: Vector2
var roam_timer := 0.0
@export var roam_retarget_time := 2.5
@export var roam_reached_dist := 60.0

signal died(agent, killer)

func _ready():
	add_to_group("agents")  # ca să îi putem găsi ușor pe toți
	hp = max_hp
	ammo = ammo_max
	_last_pos = global_position
	_load_role_logic()

func _blocked_to_target(target_pos: Vector2) -> bool:
	var params := PhysicsRayQueryParameters2D.create(global_position, target_pos)
	params.collision_mask = wall_mask
	params.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(params).is_empty()

func _tangent_dir_from_collision(desired_vel: Vector2) -> Vector2:
	if get_slide_collision_count() == 0:
		return Vector2.ZERO
	var c := get_slide_collision(0)
	var n: Vector2 = c.get_normal()
	var t := Vector2(-n.y, n.x).normalized()
	if t.dot(desired_vel) < 0.0:
		t = -t
	return t

func _is_dir_blocked(dir: Vector2) -> bool:
	if dir.length() < 0.01:
		return false
	var from := global_position
	var to := from + dir.normalized() * avoid_probe
	var params := PhysicsRayQueryParameters2D.create(from, to)
	params.collision_mask = wall_mask
	params.exclude = [get_rid()]
	return not get_world_2d().direct_space_state.intersect_ray(params).is_empty()

func _pick_unblocked_dir(preferred: Vector2, delta: float) -> Vector2:
	if avoid_lock > 0.0 and avoid_dir != Vector2.ZERO and not _is_dir_blocked(avoid_dir):
		avoid_lock -= delta
		return avoid_dir

	# normal search...
	var base := preferred.normalized()
	if base == Vector2.ZERO:
		return Vector2.ZERO
	if not _is_dir_blocked(base):
		avoid_dir = Vector2.ZERO
		avoid_lock = 0.0
		return base

	var step := deg_to_rad(avoid_angle_step_deg)
	for i in range(1, avoid_steps + 1):
		var d1 := base.rotated(step * i)
		if not _is_dir_blocked(d1):
			avoid_dir = d1; avoid_lock = avoid_lock_time
			return d1
		var d2 := base.rotated(-step * i)
		if not _is_dir_blocked(d2):
			avoid_dir = d2; avoid_lock = avoid_lock_time
			return d2
	return Vector2.ZERO

func move_towards(target_pos: Vector2, delta: float, speed_mult := 1.0, sep_dist := 60.0, sep_weight := 0.8) -> void:
	# 1) Compute preferred seek direction (your old behavior)
	var dir := get_path_dir(target_pos)
	var sep := get_separation_dir(sep_dist)
	if sep != Vector2.ZERO:
		dir = (dir + sep * sep_weight).normalized()

	# 2) If currently in "unstuck", override direction for a short time
	if _unstuck_time > 0.0:
		_unstuck_time -= delta
		if _unstuck_dir != Vector2.ZERO:
			dir = _unstuck_dir

	move_dir = dir

	# 3) Move
	var desired_vel := dir * move_speed * speed_mult
	velocity = velocity.lerp(desired_vel, clamp(accel * delta, 0.0, 1.0))
	move_and_slide()

	# 4) Detect lack of progress
	var progressed := global_position.distance_to(_last_pos)
	_last_pos = global_position

	var collided := get_slide_collision_count() > 0
	var trying_to_move := desired_vel.length() > 1.0

	if trying_to_move and (progressed < min_progress_px or collided):
		_stuck_time += delta
	else:
		_stuck_time = 0.0

	# 5) Trigger "unstuck": pick a random direction (biased by wall tangent if colliding)
	if _stuck_time >= stuck_time_to_unstuck and _unstuck_time <= 0.0:
		_stuck_time = 0.0
		_unstuck_time = unstuck_duration

		var base_dir := Vector2.RIGHT.rotated(randf() * TAU)  # fully random
		if collided:
			# Use wall tangent to avoid bouncing back into the wall
			var c := get_slide_collision(0)
			var n := c.get_normal()
			var t := Vector2(-n.y, n.x).normalized()
			if randf() < 0.5:
				t = -t
			# Add randomness so agents don't all follow the same line
			base_dir = t.rotated(randf_range(-0.6, 0.6))

		_unstuck_dir = base_dir.normalized()

func get_separation_dir(min_dist: float = 50.0) -> Vector2:
	var push: Vector2 = Vector2.ZERO

	# ne uităm la TOȚI agenții din scenă
	for node in get_tree().get_nodes_in_group("agents"):
		var other := node as Agent
		if other == null or other == self or not other.is_alive():
			continue

		var diff: Vector2 = global_position - other.global_position
		var dist := diff.length()
		if dist <= 0.01:
			continue

		if dist < min_dist:
			# cu cât e mai aproape, cu atât împingem mai tare
			var strength := (min_dist - dist) / min_dist
			push += diff.normalized() * strength

	if push.length() == 0.0:
		return Vector2.ZERO

	return push.normalized()


func _load_role_logic():
	# Șterge AI-ul vechi dacă există
	if role_logic:
		role_logic.queue_free()
		role_logic = null
	
	var logic_node = null
	
	match role:
		Role.LEADER:
			logic_node = Leader.new()
		Role.ADVANCE:
			logic_node = Advance.new()
		Role.SUPPORT:
			logic_node = Support.new()
		Role.TANK:
			logic_node = Tank.new()
	
	if logic_node:
		add_child(logic_node)
		logic_node.agent = self
		role_logic = logic_node
		print("[Agent._load_role_logic] %s loaded %s successfully!" % [name, logic_node.get_class()])
	else:
		print("[Agent._load_role_logic] %s FAILED - no logic for role %s!" % [name, Role.keys()[role]])

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int, from_agent) -> void:
	hp -= amount
	
	# Cerere ajutor dacă HP critic
	if hp > 0 and hp < max_hp * 0.3:
		if has_node("AgentComms"):
			var agent_comms = get_node("AgentComms")
			# Verifică că AgentComms e complet inițializat
			if agent_comms and agent_comms.has_method("request_assist") and agent_comms.comms_manager:
				var urgency = 5 if hp < max_hp * 0.15 else 3
				agent_comms.request_assist(global_position, urgency)
				print("[Agent] %s cere ajutor! (HP: %d/%d, urgency: %d)" % [
					id, hp, max_hp, urgency
				])
	
	if hp <= 0:
		if team:
			team.remove_member(self)
		emit_signal("died", self, from_agent)
		queue_free()


func _try_shoot() -> void:
	if not perception:
		return

	var enemies = perception.get_visible_enemies()
	if enemies.is_empty():
		# nu avem țintă, ne uităm în direcția de mers
		aim_dir = move_dir
		return

	# căutăm cel mai apropiat inamic cu linie de tragere liberă
	var best_target: Agent = null
	var best_dist := INF

	for e in enemies:
		var enemy := e as Agent
		if enemy == null:
			continue

		# NU tragem dacă avem perete între noi și el
		if not has_line_of_sight_to(enemy):
			continue

		var d := enemy.global_position.distance_to(global_position)
		if d < best_dist:
			best_dist = d
			best_target = enemy

	# dacă niciun inamic nu are LOS liber → nu tragem
	if best_target == null:
		aim_dir = move_dir
		return

	# aici avem o țintă cu LOS liber -> tragem
	fire_cooldown = 1.0 / fire_rate

	var bullet_scene = preload("res://scenes/bullets/Bullet.tscn")
	var bullet = bullet_scene.instantiate() as Bullet

	var dir: Vector2 = (best_target.global_position - global_position).normalized()
	bullet.direction = dir
	bullet.shooter = self
	bullet.damage = damage_per_shot

	aim_dir = dir

	bullet.global_position = $GunPivot/GunSprite/Muzzle.global_position
	get_tree().current_scene.add_child(bullet)

	print(name, " trage spre ", best_target.name, " cu dir=", dir)

	
func _update_poses(delta: float) -> void:
	if aim_dir.length() <= 0.1:
		return

	# agentul tău e desenat cu fața în jos => compensăm cu -PI/2
	var body_angle = aim_dir.angle()

	# corpul se întoarce mai lent
	visual.rotation = lerp_angle(
	visual.rotation,
	body_angle,
	body_turn_speed * delta)
	
	gun_pivot.rotation = lerp_angle(
		gun_pivot.rotation,
		body_angle,
		gun_turn_speed * delta
	)

func _physics_process(delta: float) -> void:
	# (your movement/roam/role logic can run before this)

	if perception.get_visible_enemies().is_empty():
		aim_dir = move_dir.normalized()

	_update_poses(delta)

	fire_cooldown -= delta
	if fire_cooldown <= 0.0:
		_try_shoot()


func set_role(new_role: Role):
	role = new_role

	var sprite := $Sprite2D

	if team == null:
		return

	# TEAM A (id = 0)
	if team.id == 0:
		if role == Role.LEADER:
			# Leader strong blue
			sprite.modulate = Color(0.3, 0.5, 1.0)
		else:
			# Other roles light blue
			sprite.modulate = Color(0.6, 0.75, 1.0)

	# TEAM B (id = 1)
	elif team.id == 1:
		if role == Role.LEADER:
			# Leader strong pink
			sprite.modulate = Color(1.0, 0.3, 0.7)
		else:
			# Other roles light pink
			sprite.modulate = Color(1.0, 0.6, 0.8)

## === CALLBACKS PENTRU MESAJE === ##

func on_teammate_status(message: Message) -> void:
	# Procesare status update
	if role_logic and role_logic.has_method("on_teammate_status"):
		role_logic.on_teammate_status(message)

func on_teammate_move(message: Message) -> void:
	if role_logic and role_logic.has_method("on_teammate_move"):
		role_logic.on_teammate_move(message)

func on_assist_request(message: Message) -> void:
	# Support răspunde prioritar
	if role == Role.SUPPORT:
		print("[Agent] %s primit ASSIST de la %s (urgency: %d)" % [
			id, message.sender, message.content.urgency
		])
	
	if role_logic and role_logic.has_method("on_assist_request"):
		role_logic.on_assist_request(message)

func on_focus_target(message: Message) -> void:
	if role_logic and role_logic.has_method("on_focus_target"):
		role_logic.on_focus_target(message)

func on_teammate_retreat(message: Message) -> void:
	if role_logic and role_logic.has_method("on_teammate_retreat"):
		role_logic.on_teammate_retreat(message)

func on_objective_assigned(message: Message) -> void:
	if role_logic and role_logic.has_method("on_objective_assigned"):
		role_logic.on_objective_assigned(message)

## Wrapper pentru backwards compatibility
func receive_message(message: Message) -> void:
	# Delegare la AgentComms
	if has_node("AgentComms"):
		get_node("AgentComms").receive_message(message)
	
func get_path_dir(target_pos: Vector2) -> Vector2:
	var dir := target_pos - global_position
	if dir.length() < 1.0:
		return Vector2.ZERO
	return dir.normalized()

func has_line_of_sight_to(target: Agent) -> bool:
	if target == null:
		return false

	var space := get_world_2d().direct_space_state
	var from := global_position
	# Aim slightly at the center of the target to avoid skimming edges
	var to := target.global_position

	var params := PhysicsRayQueryParameters2D.create(from, to)
	
	# FIX 1: Use the variable wall_mask instead of hardcoded 1
	params.collision_mask = wall_mask 
	
	# FIX 2: Exclude the shooter so the ray doesn't hit the agent's own hitbox
	params.exclude = [get_rid()] 

	var hit := space.intersect_ray(params)

	# If the ray hits nothing, the path is clear (since we only mask walls)
	if hit.is_empty():
		return true

	# If we hit something (and since we only check walls), line of sight is blocked
	return false
