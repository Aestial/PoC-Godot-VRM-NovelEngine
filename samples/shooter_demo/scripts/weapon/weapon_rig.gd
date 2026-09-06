extends Node3D
class_name WeaponRig

## Character-private weapon system ("body", in MCC terms: reachable only by the
## character's own ActionNodes — SHOOT / AIM / RELOAD act as the public API).
##
## Responsibilities:
## - ammo/reload/fire-rate/spread state machine
## - hitscan resolution from the active viewport camera (fixed center crosshair)
## - body-turn-to-camera flag (CharacterCollisionShape reads mesh_faces_camera_direction)
## - FX/SFX/camera-kick requests per shot
##
## Node layout (inside CollisionShape3D of the shooter character):
##   WeaponRig (this script)
##   ├── Gun          (visual, optional replacement via gun_scene)
##   └── Muzzle       (Node3D marker where tracers/flash spawn)

signal shot_fired(result: Dictionary)
signal aim_changed(active: bool)
signal reload_finished
signal ammo_changed(mag: int, reserve: int)
signal target_hit(position: Vector3, damage: float)

const DEFAULT_GUN: PackedScene = preload("res://samples/shooter_demo/weapons/rifle_placeholder.tscn")

const COLLISION_MASK: int = 1 | 4 # world + shootable

@export var config: WeaponConfig
@export var gun_scene: PackedScene
## Extra character bodies that bullets pass through without interacting
## (auto-filled with everything in the ControllableCharacter group).
@export var shoot_through_group: StringName = &"ControllableCharacter"

var ammo_in_mag: int = 0
var reserve_ammo: int = 0
var is_reloading: bool = false
var aim_active: bool = false

var _config: WeaponConfig
var _character: Node3D
var _collision_shape: Node
var _camera: Node # ThirdPersonCamera
var _muzzle: Node3D
var _gun: Node3D

var _fire_cooldown: float = 0.0
var _spread_bloom: float = 0.0
var _recent_shot: float = 0.0
var _reload_elapsed: float = 0.0


func _ready() -> void:
	_collision_shape = get_parent()
	_character = _collision_shape.get_parent()
	_camera = _character.get_node("ThirdPersonCamera") if _character.has_node("ThirdPersonCamera") else null

	_config = config if config != null else WeaponConfig.new()
	ammo_in_mag = _config.mag_size
	reserve_ammo = _config.reserve_size
	ammo_changed.emit(ammo_in_mag, reserve_ammo)

	_spawn_gun()
	_muzzle = get_node_or_null("Muzzle")


func _spawn_gun() -> void:
	var scene: PackedScene = gun_scene if gun_scene != null else DEFAULT_GUN
	_gun = scene.instantiate()
	add_child(_gun)
	if _gun.has_node("Muzzle"):
		_muzzle = _gun.get_node("Muzzle")


func _process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	if _recent_shot > 0.0:
		_recent_shot = maxf(0.0, _recent_shot - delta)

	# Spread bloom decays while not firing.
	_spread_bloom = maxf(0.0, _spread_bloom - _config.bloom_decay_rate * delta)

	# Reload timer.
	if is_reloading:
		_reload_elapsed += delta
		if _reload_elapsed >= _config.reload_time:
			var needed: int = _config.mag_size - ammo_in_mag
			var taken: int = mini(needed, reserve_ammo)
			ammo_in_mag += taken
			reserve_ammo -= taken
			is_reloading = false
			ammo_changed.emit(ammo_in_mag, reserve_ammo)
			reload_finished.emit()

	# Body turns to face the camera while aiming or shortly after a shot,
	# otherwise the collision-shape script keeps facing the movement direction.
	if _collision_shape and _collision_shape.get("mesh_faces_camera_direction") != null:
		_collision_shape.mesh_faces_camera_direction = aim_active or _recent_shot > 0.0


## --- Public state queries (used by the action API / HUD) ---

func can_fire_now() -> bool:
	return not is_reloading and _fire_cooldown <= 0.0 and ammo_in_mag > 0

func can_reload() -> bool:
	return not is_reloading and ammo_in_mag < _config.mag_size and reserve_ammo > 0

func get_state() -> Dictionary:
	return {
		"ammo": ammo_in_mag,
		"reserve": reserve_ammo,
		"mag_size": _config.mag_size,
		"automatic": _config.automatic,
		"reloading": is_reloading,
		"can_fire": can_fire_now(),
	}


## Live spread (aim/base + current bloom) in degrees — drives crosshair size.
func get_current_spread_degrees() -> float:
	var base := _config.aim_spread_degrees if aim_active else _config.spread_degrees
	return base + _spread_bloom


func start_reload() -> void:
	if not can_reload():
		return
	is_reloading = true
	_reload_elapsed = 0.0
	SfxBank.play_reload(get_tree().current_scene)
	ammo_changed.emit(ammo_in_mag, reserve_ammo)


func cancel_reload() -> void:
	if is_reloading:
		is_reloading = false


func set_aim_active(active: bool) -> void:
	if active == aim_active:
		return
	aim_active = active
	aim_changed.emit(active)


func play_dry_sound() -> void:
	SfxBank.play_shot(get_tree().current_scene, 0.0, false)


## --- Firing ---

func fire() -> bool:
	if not can_fire_now():
		return false

	ammo_in_mag -= 1
	ammo_changed.emit(ammo_in_mag, reserve_ammo)
	_fire_cooldown = 1.0 / _config.fire_rate
	_recent_shot = 0.4

	var spread_deg: float = _config.aim_spread_degrees if aim_active else _config.spread_degrees
	spread_deg += _spread_bloom
	_spread_bloom = minf(_spread_bloom + _config.bloom_per_shot, _config.max_bloom)

	var result: Dictionary = _resolve_shot(spread_deg)

	SfxBank.play_shot(get_tree().current_scene, randf_range(-0.05, 0.05), true)
	_spawn_muzzle_flash()
	if _camera and _camera.has_method("add_recoil"):
		_camera.add_recoil(_config.recoil_pitch + randf_range(-0.15, 0.15), randf_range(-_config.recoil_yaw, _config.recoil_yaw))

	shot_fired.emit(result)
	if result.get("hit", false) and result.get("damaged", false):
		target_hit.emit(result.get("position", Vector3.ZERO), _config.damage)
	return true


func _resolve_shot(spread_deg: float) -> Dictionary:
	var origin: Vector3
	var dir: Vector3
	var cam := get_viewport().get_camera_3d()
	if cam:
		var vp_size: Vector2 = get_viewport().get_visible_rect().size
		origin = cam.project_ray_origin(vp_size * 0.5)
		dir = cam.project_ray_normal(vp_size * 0.5)
	else: # Headless/fallback: fire along the character camera pivot.
		origin = _character.global_position + Vector3.UP * 1.4
		dir = -_character.global_transform.basis.z if _camera == null or not _camera.has_method("get_cam_forward") else _camera.get_cam_forward()

	var spread: float = deg_to_rad(spread_deg)
	if spread > 0.0:
		var right: Vector3
		var up: Vector3
		if cam:
			right = cam.global_transform.basis.x
			up = cam.global_transform.basis.y
		else:
			up = Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
			right = up.cross(dir).normalized()
		dir = dir.rotated(right, randf_range(-spread, spread)).rotated(up, randf_range(-spread, spread))
		dir = dir.normalized()

	var to: Vector3 = origin + dir * _config.max_range

	var params := PhysicsRayQueryParameters3D.create(origin, to, COLLISION_MASK)
	params.exclude = _get_pass_through_rids()
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(params)

	var result: Dictionary = {
		"origin": origin,
		"end": to,
		"hit": false,
		"damaged": false,
	}
	if not hit.is_empty():
		result["hit"] = true
		result["position"] = hit.get("position", to)
		result["normal"] = hit.get("normal", Vector3.UP)
		var collider: Object = hit.get("collider")
		result["collider"] = collider
		var dmg_node := _find_damageable(collider)
		if dmg_node != null:
			dmg_node.take_damage(_config.damage, result)
			result["damaged"] = true

	# Tracer from the muzzle to the shot end point.
	FxBank.tracer(get_tree().current_scene, _get_muzzle_origin(), result.get("position", result["end"]), _config.tracer_color)
	if result["hit"]:
		FxBank.impact(get_tree().current_scene, result["position"], result["normal"])
		# Leave a bullet hole on plain surfaces (targets show flash + popups instead).
		if not result["damaged"]:
			FxBank.bullet_hole(get_tree().current_scene, result["position"], result["normal"])
	return result


func _get_muzzle_origin() -> Vector3:
	if _muzzle and is_instance_valid(_muzzle):
		return _muzzle.global_position
	return _character.global_position + Vector3.UP * 1.4


func _get_pass_through_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if _character is CollisionObject3D:
		rids.append((_character as CollisionObject3D).get_rid())
	for node in get_tree().get_nodes_in_group(shoot_through_group):
		if node is CollisionObject3D and node != _character:
			rids.append((node as CollisionObject3D).get_rid())
	return rids


func _find_damageable(collider: Object) -> Node:
	var node := collider as Node
	while node != null:
		if node.is_in_group("ShootableTargets") and node.has_method("take_damage"):
			return node
		node = node.get_parent()
	return null


func _spawn_muzzle_flash() -> void:
	var anchor := _muzzle if _muzzle else self
	FxBank.muzzle_flash(anchor)
