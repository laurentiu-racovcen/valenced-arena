extends Node

# default match values
var round_time_seconds: int = 30
var num_rounds: int = 1
var game_mode: Enums.GameMode = Enums.GameMode.SURVIVAL    # "survival" | "koth" | "ctf"
var selected_map: String = ""  # Path to selected map scene, empty = use default for mode
