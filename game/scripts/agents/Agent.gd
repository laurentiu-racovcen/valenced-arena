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
		return
	var target = enemies[0]
	fire_cooldown = 1.0 / fire_rate

	var bullet_scene = preload("res://scenes/bullets/Bullet.tscn")
	var bullet = bullet_scene.instantiate() as Bullet
	
	# Setează proprietățile ÎNAINTE de add_child
	var dir = (target.global_position - global_position).normalized()
	bullet.direction = dir
	bullet.shooter = self
	bullet.damage = damage_per_shot
	
	# Spawn position
	var spawn_offset = dir * 100.0
	bullet.global_position = global_position + spawn_offset
	
	# Acum adaugă în scenă
	get_tree().current_scene.add_child(bullet)

	print(name, " trage spre ", target.name, " cu dir=", dir)


func _physics_process(delta: float) -> void:
	# AI-ul controlează mișcarea prin role_logic
	# Nu mai facem mișcare aici!
	
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
