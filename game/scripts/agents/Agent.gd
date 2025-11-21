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
@export var los_range: float = 1000.0
@onready var perception: AgentPerception = $AgentPerception

var hp: int
var ammo: int
var id: String = ""
var team
var map: GameMap
var fire_cooldown: float = 2.0

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

	# îl spawnăm un pic în fața agentului, nu exact în el
	var spawn_offset = dir * 100.0
	bullet.global_position = global_position + spawn_offset

	print(name, " trage spre ", target.name, " cu dir=", dir)


func _physics_process(delta: float) -> void:
	# mișcare simplă de test
	var t = Time.get_ticks_msec() / 1000.0
	var dir = Vector2.RIGHT.rotated(t)
	velocity = dir * move_speed
	move_and_slide()

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
