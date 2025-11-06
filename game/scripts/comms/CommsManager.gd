extends Node
class_name CommsManager

enum CommsMode { NO_COMMS, RING, HUB, DISTANCE, TIME_LIMITED, UNLIMITED }

var mode: CommsMode = CommsMode.UNLIMITED

func send_message(from_agent, msg: Dictionary) -> void:
    # aici veți implementa filtrarea în funcție de mod
    pass
