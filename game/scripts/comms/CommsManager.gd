extends Node
class_name CommsManager

var agents: Dictionary = {}

func register_agent(id: String, agent) -> void:
	agents[id] = agent

func send_message(msg: Dictionary) -> void:
	var to := String(msg.get("to", ""))
	if to == "*" or to == "":
		for a in agents.values():
			if a.id != msg.get("from"):
				a.receive_message(msg)
	elif agents.has(to):
		agents[to].receive_message(msg)
