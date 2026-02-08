extends CharacterBody2D

@export var can_move: bool = true
@export var SPEED := 200
@export var health := 10
@export var atk: int = 1 * Inv.get_count("sword_lvl")
var is_dead := false
var can_throw: bool = true
var eqp: int = 1 
var kunai_maxammo : int = 10
var kunai_ammo: int
var shuriken_maxammo : int = 5
var shuriken_ammo: int
var max_stamina: int = 100
var stamina: int = 100

var last_direction: Vector2 = Vector2.RIGHT
var is_attacking: bool = false
var is_throwing: bool = false
var hitbox_offset: Vector2

#Finisher
var combo_count := 0
var combo_timer := 0.0
const COMBO_WINDOW := 2.0
var finisher_target: Node2D = null


#Knockback
var knockback_velocity: Vector2 = Vector2.ZERO
var knockback_strength := 300.0
var knockback_friction := 1400.0
var is_hit := false
var enemy_health : int

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
@onready var health_bar: ProgressBar = $CanvasLayer/health_bar
@onready var stamina_bar: ProgressBar = $"CanvasLayer/stamina bar"
@onready var cords: Label = $CanvasLayer/cords


#throw animations, throw_up, throw_down, throw_right

func _ready() -> void:
	hitbox_offset = hitbox.position
	hitbox.monitoring = false

func _physics_process(delta: float) -> void:
	shuriken_ammo = Inv.get_count("shuriken")
	kunai_ammo = Inv.get_count("kunai")
	cords.text = str(Vector2i(global_position))
	health_bar.value = float(health) / 10 * health_bar.max_value
	stamina_bar.value = float(stamina)
	if is_dead:
		velocity = Vector2.ZERO
		return

	# Knockback
	if knockback_velocity.length() > 1:
		velocity = knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(
			Vector2.ZERO,
			knockback_friction * delta
		)
		move_and_slide()
		return

	#Finsiher
	if combo_count > 0:
		combo_timer += delta
		if combo_timer > COMBO_WINDOW:
			reset_combo()


	if not is_attacking:
		hitbox.monitoring = false

	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()

	if Input.is_action_pressed("Sprint") and stamina > 0 and velocity != Vector2.ZERO:
		SPEED = 400
		stamina -= float(25) * delta
		$CanvasLayer/regen_timer.stop()
	else:
		SPEED = 200
		if stamina < max_stamina and $CanvasLayer/regen_timer.is_stopped():
			$CanvasLayer/regen_timer.start()

	stamina = clamp(stamina, 0, max_stamina)

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
		var thrown := false

		if eqp == 1 and kunai_ammo > 0:
			play_throw_animation(last_direction)
			throw_kunai()
			Inv.remove("kunai" , 1) 
			thrown = true

		elif eqp == 2 and shuriken_ammo > 0:
			play_throw_animation(last_direction)
			throw_shruiken()
			Inv.remove("shuriken" , 1) 
			thrown = true

		if thrown:
			can_throw = false
			$CanvasLayer/kunai.self_modulate = Color(1,1,1,0.5)
			$CanvasLayer/shuriken.self_modulate = Color(1,1,1,0.5)
			cd.start()

	
	kunai_amm.text = str(kunai_ammo)
	shuriken_amm.text = str(shuriken_ammo)
	
	if can_move:
		process_movement()
	else:
		velocity = Vector2.ZERO
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
	if is_attacking or is_hit or is_throwing:
		return

	if velocity != Vector2.ZERO:
		play_animation("run", last_direction)
	else:
		play_animation("idle", last_direction)

func play_throw_animation(dir: Vector2):
	is_throwing = true

	if dir.x != 0:
		animated_sprite_2d.flip_h = dir.x < 0
		animated_sprite_2d.play("throw_right")
	elif dir.y < 0:
		animated_sprite_2d.play("throw_up")
	else:
		animated_sprite_2d.play("throw_down")


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
	await animated_sprite_2d.animation_finished 
	is_attacking = false


func _on_animated_sprite_2d_animation_finished() -> void:
	if is_attacking:
		is_attacking = false
		hitbox.monitoring = false

	if is_throwing:
		is_throwing = false
		can_move = true



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
		enemy_health = body.health
		finisher_target = body 
		register_combo_hit()



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
	$CanvasLayer/kunai.self_modulate = Color(1,1,1,1)
	$CanvasLayer/shuriken.self_modulate = Color(1,1,1,1)

func regen():
	stamina += 15 
	$CanvasLayer/regen_timer.wait_time = randf_range(0.5, 2)
	$CanvasLayer/regen_timer.start()

func _on_regen_timer_timeout() -> void:
	if stamina < max_stamina:
		stamina += 15
	else:
		$CanvasLayer/regen_timer.stop()

func register_combo_hit():
	if combo_count == 0:
		combo_timer = 0.0

	combo_count += 1

	if combo_count >= 4 and enemy_health <= 3:
		finisher()
		reset_combo()
		

func reset_combo():
	combo_count = 0
	combo_timer = 0.0

func finisher():
	if finisher_target == null or not is_instance_valid(finisher_target):
		return

	can_move = false
	is_attacking = false
	is_throwing = false

	# direction from enemy to player
	var dir := (global_position - finisher_target.global_position).normalized()

	# first dramatic pause
	get_tree().paused = true
	await get_tree().create_timer(0.4, true).timeout
	get_tree().paused = false
	
	# flash
	$CanvasLayer/ColorRect.visible = true
	await get_tree().create_timer(0.05).timeout
	$CanvasLayer/ColorRect.visible = false
	
	# teleport behind enemy
	var offset := -200.0
	global_position = finisher_target.global_position + dir * offset

	# face the enemy
	last_direction = -dir

	# 🔥 APPLY FINISHER DAMAGE (guaranteed kill)
	finisher_target.hurt(global_position, 10)

	Camera.shake(2.0)

	# final hit-stop
	get_tree().paused = true
	await get_tree().create_timer(0.4, true).timeout
	get_tree().paused = false

	can_move = true
