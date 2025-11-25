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
@export var los_range: float = 1400.0
@onready var perception: AgentPerception = $AgentPerception
@onready var visual = $Visual

@onready var gun_pivot = $GunPivot

var move_dir: Vector2 = Vector2.ZERO
var aim_dir: Vector2 = Vector2.ZERO
@export var body_turn_speed: float = 6.0
@export var gun_turn_speed: float = 10.0


var hp: int
var ammo: int
var id: String = ""
var team
var map: GameMap
var fire_cooldown: float = 0.0

signal died(agent, killer)

func _ready():
	hp = max_hp
	ammo = ammo_max
	_load_role_logic()

func _load_role_logic():
	var script_path := ""
	match role:
		Role.LEADER:
			script_path = "res://scripts/agents/roles/Leader.gd"
		Role.ADVANCE:
			script_path = "res://scripts/agents/roles/Advance.gd"
		Role.SUPPORT:
			script_path = "res://scripts/agents/roles/Support.gd"
		Role.TANK:
			script_path = "res://scripts/agents/roles/Tank.gd"
	if script_path != "":
		var logic = load(script_path).new()
		add_child(logic)
		logic.agent = self

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int, from_agent) -> void:
	hp -= amount

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
		aim_dir = move_dir
		return
	var target = enemies[0]  # deocamdată luăm primul
	fire_cooldown = 1.0 / fire_rate

	var bullet_scene = preload("res://scenes/bullets/Bullet.tscn")
	var bullet = bullet_scene.instantiate() as Bullet
	get_tree().current_scene.add_child(bullet)

	# direcția spre țintă
	var dir = (target.global_position - global_position).normalized()
	bullet.direction = dir
	bullet.owner = self
	bullet.damage = damage_per_shot

	# rotim vizualul și arma spre poziția prezisă
	aim_dir = dir
	

	bullet.global_position = $GunPivot/GunSprite/Muzzle.global_position

	print(name, " trage spre ", target.name, " cu dir=", dir)
	
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
	# mișcare simplă de test (la tine e deja ceva gen cerc)
	#var t = Time.get_ticks_msec() / 1000.0
	#move_dir = Vector2.RIGHT.rotated(t)
	#velocity = move_dir * move_speed
	#move_and_slide()

	# dacă nu avem țintă, uită-te în direcția de mișcare
	if perception.get_visible_enemies().is_empty():
		aim_dir = move_dir.normalized()

	_update_poses(delta)
	
	fire_cooldown -= delta
	if fire_cooldown <= 0:
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
