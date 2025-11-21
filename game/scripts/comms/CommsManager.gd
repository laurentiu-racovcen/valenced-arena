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
		
## Stores agents requesting help -> to be changed when implementing communication
var help_requests: Array = []

func request_help(agent: Agent):
	if not help_requests.has(agent):
		help_requests.append(agent)

func clear_help(agent: Agent):
	help_requests.erase(agent)

func get_help_request() -> Agent:
	# return the nearest or first agent needing help
	if help_requests.size() == 0:
		return null
	return help_requests[0]
