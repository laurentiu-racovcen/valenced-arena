extends CharacterBody2D
class_name Agent

enum Role { LEADER, ADVANCE, TANK, SUPPORT }

@export var role: Role = Role.ADVANCE
@export var team_id: int = 0

@export var max_hp: int = 100
@export var move_speed: float = 200.0
@export var damage_per_shot: int = 10
@export var fire_rate: float = 2.0
@export var ammo_max: int = 30
@export var reload_time: float = 2.0
@export var los_range: float = 300.0

var hp: int
var ammo: int
signal died(agent, killer)

func _ready():
	hp = max_hp
	ammo = ammo_max

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int, from_agent) -> void:
	hp -= amount
	if hp <= 0:
		emit_signal("died", self, from_agent)
		queue_free()

func _physics_process(delta: float) -> void:
	# se mișcă într-un cerc în jurul originii
	var t = Time.get_ticks_msec() / 1000.0
	var dir = Vector2.RIGHT.rotated(t)
	velocity = dir * move_speed
	move_and_slide()
