extends CharacterBody2D

# CONFIG
var speed := 100.0
var health := 3

var x := 1
var y := 1

var detect := false
var target: Node2D

# Knockback
var knockback_velocity := Vector2.ZERO
var knockback_strength := 250.0
var knockback_friction := 1200.0

# States
enum State { IDLE, ATTACK, DIE }
var state: State = State.IDLE
var is_dead := false


# NODES
@onready var up: RayCast2D = $Up
@onready var down: RayCast2D = $Down
@onready var left: RayCast2D = $Left
@onready var right: RayCast2D = $Right
@onready var timer: Timer = $Timer
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $health_bar

# READY
func _ready() -> void:
	randomize()
	timer.wait_time = randi_range(1, 4)
	timer.start()
	anim.play("idle")

# PHYSICS
func _physics_process(delta: float) -> void:
	health_bar.value = health
	if is_dead:
		velocity = Vector2.ZERO
		return

	# Knockback overrides AI
	if knockback_velocity.length() > 1:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(
			Vector2.ZERO,
			knockback_friction * delta
		)
		move_and_slide()
		return

	if detect and target:
		state = State.ATTACK
		chase()
	else:
		state = State.IDLE
		wander()

	update_animation()
	move_and_slide()

# MOVEMENT
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

# ANIMATION
func update_animation():
	match state:
		State.IDLE:
			if anim.animation != "idle":
				anim.play("idle")

		State.ATTACK:
			if anim.animation != "attack":
				anim.play("attack")

		State.DIE:
			if anim.animation != "die":
				anim.play("die")

# RANDOM DIRECTION
func _on_timer_timeout() -> void:
	timer.wait_time = randi_range(1, 4)
	x = [-1, 1].pick_random()
	y = [-1, 1].pick_random()
	timer.start()

# DETECTION
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		detect = true
		target = body

func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		detect = false
		target = null

# COMBAT
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		body.hit(global_position, 1)

func hurt(attacker_pos: Vector2, attk: int):
	if is_dead:
		return

	var dir := (global_position - attacker_pos).normalized()
	knockback_velocity = dir * knockback_strength

	# flash effect (invulnerability feedback)
	$AnimatedSprite2D.modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(0.08).timeout
	$AnimatedSprite2D.modulate = Color(1, 1, 1)
	
	health -= attk
	if health <= 0:
		die()

func die():
	$CollisionShape2D.disabled = true
	$Area2D/CollisionShape2D.disabled = true
	$hitbox/CollisionShape2D.disabled = true
	is_dead = true
	state = State.DIE
	anim.play("die")
	await anim.animation_finished
	queue_free()
