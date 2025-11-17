extends Area2D
class_name Bullet

@export var speed: float = 500
var direction: Vector2 = Vector2.ZERO
var damage: int = 10

var traveled_distance: float = 0.0
@export var max_distance: float = 2000.0

func _ready() -> void:
	# ca să fim siguri că se apelează _physics_process
	set_physics_process(true)

func _physics_process(delta: float) -> void:
	if direction == Vector2.ZERO:
		return

	var move_vec = direction * speed * delta
	global_position += move_vec

	traveled_distance += move_vec.length()
	if traveled_distance > max_distance:
		queue_free()

func _on_Bullet_body_entered(body: Node) -> void:
	# ignorăm propriul owner, ca să nu se distrugă instant
	if body == owner:
		return

	if body is Agent:
		body.take_damage(damage, owner)
		queue_free()
