extends CharacterBody2D

var speed := 100.0
var health := 10

var x := 1
var y := 1

var detect := false
var target: Node2D
var player_lastpos: Vector2

# Knockback
var knockback_velocity := Vector2.ZERO
var knockback_strength := 250.0
var knockback_friction := 1200.0

# States
enum State { IDLE, CHASE, SEARCH, DIE }
var state: State = State.IDLE
var is_dead := false

@onready var up: RayCast2D = $Up
@onready var down: RayCast2D = $Down
@onready var left: RayCast2D = $Left
@onready var right: RayCast2D = $Right
@onready var timer: Timer = $Timer
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $health_bar


func _ready() -> void:
	randomize()
	timer.wait_time = randi_range(1, 4)
	timer.start()
	play_idle(Vector2.DOWN)


func _physics_process(delta: float) -> void:
	health_bar.value = health

	if is_dead:
		velocity = Vector2.ZERO
		return

	# Knockback override
	if knockback_velocity.length() > 1:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(
			Vector2.ZERO,
			knockback_friction * delta
		)
		move_and_slide()
		return

	if detect and target:
		state = State.CHASE
		chase()
	elif state == State.SEARCH:
		move_to_lastpos()
	else:
		state = State.IDLE
		wander()

	update_animation()
	move_and_slide()


# =====================
# MOVEMENT
# =====================
func wander():
	var dir := Vector2(x, y).normalized()

	if up.is_colliding():
		dir.y = 1
	if down.is_colliding():
		dir.y = -1
	if left.is_colliding():
		dir.x = 1
	if right.is_colliding():
		dir.x = -1

	velocity = dir * speed


func chase():
	var dir := (target.global_position - global_position).normalized()
	velocity = dir * speed * 1.2


func move_to_lastpos():
	var dir := player_lastpos - global_position

	if dir.length() < 8:
		state = State.IDLE
		return

	velocity = dir.normalized() * speed * 1.2


# =====================
# ANIMATION
# =====================
func update_animation():
	if velocity == Vector2.ZERO:
		play_idle(last_move_dir())
	else:
		play_run(last_move_dir())


func last_move_dir() -> Vector2:
	if abs(velocity.x) > abs(velocity.y):
		return Vector2(sign(velocity.x), 0)
	else:
		return Vector2(0, sign(velocity.y))


func play_idle(dir: Vector2):
	if dir.x != 0:
		anim.flip_h = dir.x < 0
		anim.play("idle_right")
	elif dir.y < 0:
		anim.play("idle_up")
	else:
		anim.play("idle_down")


func play_run(dir: Vector2):
	if dir.x != 0:
		anim.flip_h = dir.x < 0
		anim.play("run_right")
	elif dir.y < 0:
		anim.play("run_up")
	else:
		anim.play("run_down")


# =====================
# RANDOM WANDER
# =====================
func _on_timer_timeout() -> void:
	timer.wait_time = randi_range(1, 4)
	x = [-1, 1].pick_random()
	y = [-1, 1].pick_random()
	timer.start()


# =====================
# DETECTION
# =====================
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		detect = true
		target = body


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		player_lastpos = body.global_position
		target = null
		detect = false
		state = State.SEARCH


# =====================
# COMBAT
# =====================
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.hit(global_position, 2)


func hurt(attacker_pos: Vector2, attk: int):
	if is_dead:
		return

	var dir := (global_position - attacker_pos).normalized()
	knockback_velocity = dir * knockback_strength

	anim.modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(0.08).timeout
	anim.modulate = Color(1, 1, 1)

	health -= attk
	if health <= 0:
		die()


func die():
	is_dead = true
	velocity = Vector2.ZERO
	state = State.DIE
	anim.play("die")
	await anim.animation_finished
	queue_free()
