extends Node
class_name Support

var agent: Agent
var current_assist_target: Agent = null
var assist_urgency: int = 0
var last_assist_time: float = 0.0

const ASSIST_TIMEOUT: float = 10.0
const ASSIST_DISTANCE: float = 200.0

func _physics_process(delta: float) -> void:
	if not agent or not agent.is_alive():
		return

	var target_pos: Vector2
	var current_time := Time.get_ticks_msec() / 1000.0

	# 0. Dacă are inamic în față și trage în perete → mută-te!
	var enemies := agent.perception.get_visible_enemies()
	if enemies.size() > 0:
		enemies.sort_custom(
			func(a, b):
				return a.global_position.distance_to(agent.global_position) < b.global_position.distance_to(agent.global_position)
		)
		var enemy: Agent = enemies[0] as Agent

		var to_enemy: Vector2 = enemy.global_position - agent.global_position
		var dist := to_enemy.length()
		var desired_dist := 50.0

		if (not agent.has_line_of_sight_to(enemy)) or dist > desired_dist:
			var dir_norm = to_enemy / max(dist, 0.001)
			target_pos = enemy.global_position - dir_norm * desired_dist

			var dir: Vector2 = agent.get_path_dir(target_pos)
			var sep: Vector2 = agent.get_separation_dir(60.0)  # 60 = distanța minimă dorită

			if sep != Vector2.ZERO:
				# combinăm direcția principală cu separarea
				dir = (dir + sep * 0.8).normalized()

			agent.move_dir = dir
			agent.move_towards(target_pos, delta, 0.95, 95.0, 1.1)

## === CALLBACK PENTRU ASSIST === ##
func on_assist_request(message: Message) -> void:
	
	if not agent or not agent.team:
		return
	
	var sender = agent.team.members.filter(func(m): return m.id == message.sender or m.name == message.sender)
	if sender.is_empty():
		return
	
	var requesting_agent = sender[0]
	var urgency = message.content.urgency
	
	print("[Support] %s primește ASSIST de la %s (urgency: %d, current: %d)" % [
		agent.id, requesting_agent.id, urgency, assist_urgency
	])
	
	if not current_assist_target or urgency > assist_urgency:
		current_assist_target = requesting_agent
		assist_urgency = urgency
		last_assist_time = Time.get_ticks_msec() / 1000.0
		
		print("[Support] %s RĂSPUNDE la ASSIST de la %s! Mergând în ajutor..." % [
			agent.id, requesting_agent.id
		])

func _get_tank() -> Agent:
	if not agent or not agent.team:
		return null
	
	for m in agent.team.members:
		if m.role == Agent.Role.TANK and m.is_alive():
			return m
	return null
