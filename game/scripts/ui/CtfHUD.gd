extends Control
class_name CtfHUD

# Preload classes
const FlagClass = preload("res://scripts/modes/Flag.gd")

## CTF-specific HUD overlay
## Shows flag status, off-screen indicators, and team scores

## References
var ctf_mode = null
var camera: Camera2D = null

## Flag status icons
@onready var blue_flag_status: Control = $BlueFlag
@onready var red_flag_status: Control = $RedFlag
@onready var blue_label: Label = $BlueFlag/Label
@onready var red_label: Label = $RedFlag/Label

## Off-screen indicator settings
const EDGE_MARGIN: float = 50.0
const INDICATOR_SIZE: float = 30.0

## Colors
const BLUE_COLOR := Color(0.2, 0.5, 1.0)
const RED_COLOR := Color(1.0, 0.3, 0.3)

## Update timer
var update_timer: float = 0.0
const UPDATE_INTERVAL: float = 0.1

func _ready() -> void:
	# Don't process until connected
	set_process(false)

func setup(_ctf_mode, _camera: Camera2D = null) -> void:
	ctf_mode = _ctf_mode
	camera = _camera
	set_process(true)

func _process(delta: float) -> void:
	update_timer -= delta
	if update_timer <= 0:
		update_timer = UPDATE_INTERVAL
		_update_flag_status()
	
	# Always update indicators (for smooth movement)
	queue_redraw()

func _update_flag_status() -> void:
	if not ctf_mode:
		return
	
	# Update blue flag status
	if ctf_mode.blue_flag:
		var status = _get_flag_status_text(ctf_mode.blue_flag)
		if blue_label:
			blue_label.text = status
	
	# Update red flag status
	if ctf_mode.red_flag:
		var status = _get_flag_status_text(ctf_mode.red_flag)
		if red_label:
			red_label.text = status

func _get_flag_status_text(flag) -> String:
	match flag.state:
		FlagClass.State.AT_BASE:
			return "AT BASE"
		FlagClass.State.CARRIED:
			var carrier_name = flag.carrier.name if flag.carrier else "???"
			return "CARRIED by " + carrier_name
		FlagClass.State.DROPPED:
			return "DROPPED (%.0fs)" % flag.drop_timer
	return "???"

func _draw() -> void:
	if not ctf_mode:
		return
	
	# Get viewport size
	var viewport_size = get_viewport_rect().size
	
	# Draw off-screen indicators for flags
	if ctf_mode.blue_flag and ctf_mode.blue_flag.state != FlagClass.State.AT_BASE:
		_draw_flag_indicator(ctf_mode.blue_flag, BLUE_COLOR, viewport_size)
	
	if ctf_mode.red_flag and ctf_mode.red_flag.state != FlagClass.State.AT_BASE:
		_draw_flag_indicator(ctf_mode.red_flag, RED_COLOR, viewport_size)

func _draw_flag_indicator(flag, color: Color, viewport_size: Vector2) -> void:
	# Get flag world position
	var flag_pos = flag.global_position
	
	# Convert to screen position
	var screen_pos = flag_pos
	if camera:
		screen_pos = camera.get_viewport().get_canvas_transform() * flag_pos
	
	# Check if on screen
	var margin = EDGE_MARGIN
	if screen_pos.x >= margin and screen_pos.x <= viewport_size.x - margin and \
	   screen_pos.y >= margin and screen_pos.y <= viewport_size.y - margin:
		# On screen, draw small marker
		draw_circle(screen_pos, 8, color)
		return
	
	# Off screen - draw edge indicator
	var center = viewport_size / 2
	var direction = (screen_pos - center).normalized()
	
	# Calculate edge position
	var edge_pos = _get_edge_position(center, direction, viewport_size, margin)
	
	# Draw arrow indicator
	_draw_arrow_indicator(edge_pos, direction, color)
	
	# Draw distance text
	if camera:
		var player_pos = camera.global_position
		var distance = player_pos.distance_to(flag_pos)
		var font = ThemeDB.fallback_font
		var font_size = ThemeDB.fallback_font_size
		draw_string(font, edge_pos + Vector2(-20, 25), "%.0fm" % (distance / 10), HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)

func _get_edge_position(center: Vector2, direction: Vector2, viewport_size: Vector2, margin: float) -> Vector2:
	# Calculate where the direction vector intersects the screen edge
	var half_size = viewport_size / 2 - Vector2(margin, margin)
	
	var t_x = INF
	var t_y = INF
	
	if abs(direction.x) > 0.001:
		t_x = half_size.x / abs(direction.x)
	if abs(direction.y) > 0.001:
		t_y = half_size.y / abs(direction.y)
	
	var t = min(t_x, t_y)
	return center + direction * t

func _draw_arrow_indicator(pos: Vector2, direction: Vector2, color: Color) -> void:
	# Draw triangle pointing toward the flag
	var size = INDICATOR_SIZE
	var perp = Vector2(-direction.y, direction.x)
	
	var points = PackedVector2Array([
		pos + direction * size * 0.6,
		pos - direction * size * 0.4 + perp * size * 0.4,
		pos - direction * size * 0.4 - perp * size * 0.4
	])
	
	draw_colored_polygon(points, color)
	
	# Draw outline
	var outline_color = Color.WHITE
	outline_color.a = 0.8
	for i in range(points.size()):
		draw_line(points[i], points[(i + 1) % points.size()], outline_color, 2.0)

## Public method to set score display (integrates with existing ScoreHUD)
func set_ctf_score(blue_captures: int, red_captures: int) -> void:
	# This can be used to show capture count
	pass
