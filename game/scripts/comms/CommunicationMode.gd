extends RefCounted
class_name CommunicationMode

## Tipuri de restricții conform documentației
enum Type {
	UNLIMITED,          ## Fără restricții
	LIMITED_DISTANCE,   ## Restricție distanță
	LIMITED_TIME,       ## Cooldown între mesaje
	LIMITED_SIZE,       ## Dimensiune maximă
	HUB_TOPOLOGY,       ## Comunicare prin hub central
	RING_TOPOLOGY,      ## Comunicare în circuit
	NEAREST_NEIGHBORS,  ## Doar cu cei mai apropiați N vecini
	NONE                ## Nicio comunicare
}

var mode_type: Type
var description: String

## Parametri pentru fiecare tip
var max_distance: float = 0.0
var cooldown: float = 0.0
var max_bytes: int = 0
var hub_agent: String = ""
var connections: Dictionary = {}
var neighbor_count: int = 3

func _init(p_type: Type = Type.UNLIMITED, params: Dictionary = {}):
	mode_type = p_type
	description = params.get("description", "")
	
	match mode_type:
		Type.LIMITED_DISTANCE:
			max_distance = params.get("max_distance", 250.0)
		Type.LIMITED_TIME:
			cooldown = params.get("cooldown", 1.0)
		Type.LIMITED_SIZE:
			max_bytes = params.get("max_bytes", 256)
		Type.HUB_TOPOLOGY:
			hub_agent = params.get("hub_agent", "")
		Type.RING_TOPOLOGY:
			connections = params.get("connections", {})
		Type.NEAREST_NEIGHBORS:
			neighbor_count = params.get("neighbor_count", 3)

func _to_string() -> String:
	return "[CommunicationMode: %s]" % Type.keys()[mode_type]
