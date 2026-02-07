extends CharacterBody2D

@export var can_move: bool = true
@export var SPEED := 300.0
@export var health := 10
@export var atk: int = 1
var is_dead := false
var can_throw: bool = true
var eqp: int = 1 
var kunai_maxammo : int = 10
var kunai_ammo: int = 10
var shuriken_maxammo : int = 5
var shuriken_ammo: int = 5



var last_direction: Vector2 = Vector2.RIGHT
var is_attacking: bool = false
var hitbox_offset: Vector2

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_strength := 300.0
var knockback_friction := 1400.0
var is_hit := false

@export var kunai_scene: PackedScene
@export var Shrukien_scene: PackedScene
@export var Bomb_scene: PackedScene

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var hitbox: Area2D = $Hitbox
@onready var swing_sword: AudioStreamPlayer2D = $SwingSword
@onready var Camera: Camera2D = $Camera2D
@onready var cd: Timer = $CD
@onready var kunai_amm: LineEdit = $CanvasLayer/kunai/kunai_amm
@onready var shuriken_amm: LineEdit = $CanvasLayer/shuriken/shuriken_amm


func _ready() -> void:
	hitbox_offset = hitbox.position
	hitbox.monitoring = false


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	# Knockback takes priority
	if knockback_velocity.length() > 1:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(
			Vector2.ZERO,
			knockback_friction * delta
		)
		move_and_slide()
		return

	if not is_attacking:
		hitbox.monitoring = false

	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()

	if Input.is_action_just_pressed("change_throw"):
		if eqp == 1:
			eqp = 2
			$CanvasLayer/kunai.visible = false
			$CanvasLayer/shuriken.visible = true
		elif eqp == 2:
			eqp = 1
			$CanvasLayer/kunai.visible = true
			$CanvasLayer/shuriken.visible = false

	if Input.is_action_just_pressed("Throwable") and not is_attacking and can_throw:
		can_throw = false
		cd.start()
		if eqp == 1 and kunai_ammo > 0:
			throw_kunai()
			kunai_ammo -= 1
		elif eqp == 2 and shuriken_ammo > 0:
			throw_shruiken()
			shuriken_ammo -= 1
	
	kunai_amm.text = str(kunai_ammo)
	shuriken_amm.text = str(shuriken_ammo)
	
	if can_move:
		process_movement()
	_process_animation()
	move_and_slide()


func process_movement() -> void:
	var direction := Input.get_vector("left", "right", "up", "down")

	if direction != Vector2.ZERO:
		velocity = direction * SPEED
		last_direction = direction
		update_hitbox_offset()
	else:
		velocity = Vector2.ZERO


func _process_animation() -> void:
	if is_attacking or is_hit:
		return

	if velocity != Vector2.ZERO:
		play_animation("run", last_direction)
	else:
		play_animation("idle", last_direction)


func play_animation(prefix: String, dir: Vector2) -> void:
	if dir.x != 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animated_sprite_2d.play(prefix + "_right")
	elif dir.y < 0:
		animated_sprite_2d.play(prefix + "_up")
	elif dir.y > 0:
		animated_sprite_2d.play(prefix + "_down")


func attack() -> void:
	is_attacking = true
	hitbox.monitoring = true

	play_animation("attack", last_direction)
	swing_sword.play()


func _on_animated_sprite_2d_animation_finished() -> void:
	if is_attacking:
		is_attacking = false

func throw_kunai():
	var k = kunai_scene.instantiate()
	k.global_position = global_position
	k.direction = last_direction
	get_tree().current_scene.add_child(k)

func throw_shruiken():
	var s = Shrukien_scene.instantiate()
	s.global_position = global_position
	s.direction = last_direction
	get_tree().current_scene.add_child(s)


func update_hitbox_offset() -> void:
	var x := hitbox_offset.x
	var y := hitbox_offset.y

	match last_direction:
		Vector2.LEFT:
			hitbox.position = Vector2(-x, y)
		Vector2.RIGHT:
			hitbox.position = Vector2(x, y)
		Vector2.UP:
			hitbox.position = Vector2(y, -x)
		Vector2.DOWN:
			hitbox.position = Vector2(-y, x)


func _on_hitbox_body_entered(body: Node) -> void:
	if is_attacking and body.is_in_group("Enemy"):
		Camera.shake(0.6)
		body.hurt(global_position, atk)


#Combat
func hit(attacker_pos: Vector2, dmg: int):
	if is_hit or is_dead:
		return

	is_hit = true
	health -= dmg

	var dir := (global_position - attacker_pos).normalized()
	knockback_velocity = dir * knockback_strength
	Camera.shake(0.9)

	# flash effect (invulnerability feedback)
	animated_sprite_2d.modulate = Color(1, 0.4, 0.4)
	await get_tree().create_timer(0.08).timeout
	animated_sprite_2d.modulate = Color(1, 1, 1)

	if health <= 0:
		die()
		return

	await get_tree().create_timer(0.2).timeout
	is_hit = false


func die():
	is_dead = true
	is_attacking = false
	hitbox.monitoring = false
	velocity = Vector2.ZERO

	animated_sprite_2d.play("dying")
	Camera.shake(1.3)

	await animated_sprite_2d.animation_finished
	queue_free() # swap with respawn if you want


func _on_cd_timeout() -> void:
	can_throw = true
