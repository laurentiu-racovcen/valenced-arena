extends Control
class_name LiveStatsOverlay

## Real-time statistics overlay - toggled with TAB key during match

@onready var left_label: RichTextLabel = $LeftPanel/StatsLabel
@onready var right_label: RichTextLabel = $RightPanel/StatsLabel

var stats_manager: StatsManager = null
var update_interval: float = 0.5  # Update every 0.5 seconds
var _timer: float = 0.0
var _match_ended: bool = false

func _ready() -> void:
	visible = false  # Start hidden
	# Find StatsManager and GameManager
	await get_tree().process_frame
	var match_node = get_tree().current_scene
	if match_node:
		stats_manager = match_node.get_node_or_null("StatsManager") as StatsManager
		# Connect to match_ended signal to hide when match ends
		var game_manager = match_node.get_node_or_null("GameManager")
		if game_manager and game_manager.has_signal("match_ended"):
			game_manager.match_ended.connect(_on_match_ended)

func _input(event: InputEvent) -> void:
	if _match_ended:
		return  # Don't allow toggle after match ended
	if event.is_action_pressed("ui_focus_next"):  # TAB key
		visible = !visible
		if visible:
			_update_stats()  # Update immediately when shown
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if _match_ended or not visible or stats_manager == null:
		return
	
	_timer += delta
	if _timer >= update_interval:
		_timer = 0.0
		_update_stats()

func _on_match_ended(_winning_team: int) -> void:
	_match_ended = true
	visible = false

func _is_end_menu_visible() -> bool:
	var match_node = get_tree().current_scene
	if match_node == null:
		return false
	
	# EndRoundMenu is added as child of GameManager
	var game_manager = match_node.get_node_or_null("GameManager")
	if game_manager:
		for child in game_manager.get_children():
			if "EndRound" in child.name:
				return true
	
	# Also check entire tree for safety
	for node in get_tree().get_nodes_in_group("end_round_menu"):
		return true
	
	return false

func _update_stats() -> void:
	if stats_manager == null:
		return
	var team_stats := stats_manager.get_team_stats()
	var t0: Dictionary = team_stats.get(0, {}) as Dictionary
	var t1: Dictionary = team_stats.get(1, {}) as Dictionary
	
	if left_label:
		left_label.text = _format_team_stats("BLUE TEAM", t0)
	if right_label:
		right_label.text = _format_team_stats("RED TEAM", t1)

func _format_team_stats(title: String, t: Dictionary) -> String:
	var kills: int = t.get("kills", 0) as int
	var deaths: int = t.get("deaths", 0) as int
	var assists: int = t.get("assists", 0) as int
	var dmg_dealt: int = t.get("damage_dealt", 0) as int
	var dmg_taken: int = t.get("damage_taken", 0) as int
	var bullets_fired: int = t.get("bullets_fired", 0) as int
	var bullets_hit: int = t.get("bullets_hit", 0) as int
	var accuracy: float = (float(bullets_hit) / float(bullets_fired) * 100.0) if bullets_fired > 0 else 0.0
	var alive: int = t.get("alive", 0) as int
	var total: int = t.get("agent_count", 0) as int
	
	# Calculate KDA ratio
	var kda: float = float(kills + assists) / float(max(deaths, 1))
	
	# Format DPS if we have timing info
	var dps: float = t.get("dps", 0.0) as float
	
	var text := "[b]%s[/b]\n" % title
	text += "[color=gray]━━━━━━━━━━━━━[/color]\n"
	text += "Alive: [b]%d/%d[/b]\n" % [alive, total]
	text += "K/D/A: [b]%d/%d/%d[/b]\n" % [kills, deaths, assists]
	text += "KDA Ratio: [b]%.2f[/b]\n" % kda
	text += "\nDamage Dealt: [b]%d[/b]\n" % dmg_dealt
	text += "Damage Taken: [b]%d[/b]\n" % dmg_taken
	if dps > 0:
		text += "DPS: [b]%.1f[/b]\n" % dps
	text += "\nBullets: [b]%d/%d[/b]\n" % [bullets_hit, bullets_fired]
	text += "Accuracy: [b]%.1f%%[/b]" % accuracy
	
	return text
