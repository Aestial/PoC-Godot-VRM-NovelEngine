extends Node3D
class_name TargetDummy

## Shootable gallery target / destructible prop base (group: ShootableTargets).
## WeaponRig already resolves damage through group + take_damage(), so these
## only need to react: damage popups, hit flash, knockdown/sink, score and
## timed respawn. Optional sine movement turns a dummy into a moving target.

enum Style { MANNEQUIN, CRATE }

signal downed(target: Node)

@export var points: int = 100
@export var style: Style = Style.MANNEQUIN
@export var respawn_time: float = 3.0

## Movement (moving gallery target): oscillates around the spawn position.
@export var moving: bool = false
@export var move_amplitude: float = 5.0
@export var move_speed: float = 0.6 # rad/s of the sine

@onready var _health: Health = $Health
@onready var _visual: MeshInstance3D = $Visual
@onready var _body: StaticBody3D = $Body

var alive: bool = true
var _base_position: Vector3
var _time: float = 0.0
var _body_layer: int = 4
var _flash_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("ShootableTargets")
	_base_position = global_position
	_body_layer = _body.collision_layer
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


func take_damage(amount: int, hit: Dictionary = {}) -> void:
	_health.take_damage(amount, hit)


func _physics_process(delta: float) -> void:
	if moving and alive:
		_time += delta
		global_position.x = _base_position.x + sin(_time * move_speed) * move_amplitude


func _on_damaged(amount: int, hit: Dictionary) -> void:
	_flash()
	var pos: Vector3 = hit.get("position", global_position + Vector3.UP)
	FxBank.popup(get_tree().current_scene, pos, "-%d" % amount, Color(1.0, 0.25, 0.25))


func _on_died(hit: Dictionary) -> void:
	alive = false
	downed.emit(self)
	_body.collision_layer = 0 # bullets pass through while down
	var sk := get_tree().get_first_node_in_group("ScoreKeeper")
	if sk and sk.has_method("register_down"):
		sk.register_down(self)
	var pos: Vector3 = _visual.global_position + Vector3.UP * 1.1
	FxBank.popup(get_tree().current_scene, pos, "+%d" % points, Color(0.85, 0.8, 0.4))
	_down_tween()


func _down_tween() -> void:
	var tween := create_tween()
	match style:
		Style.MANNEQUIN:
			tween.set_parallel(true)
			tween.tween_property(self, "rotation", Vector3(deg_to_rad(-85.0), 0, 0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tween.tween_property(self, "position:y", _base_position.y - 0.4, 0.45)
		Style.CRATE:
			tween.set_parallel(true)
			tween.tween_property(self, "rotation", Vector3(0, 0, randf_range(-0.6, 0.6)), 0.3)
			tween.tween_property(self, "position:y", _base_position.y - 1.6, 0.5)
	await tween.finished
	visible = false
	await get_tree().create_timer(respawn_time).timeout
	if is_inside_tree():
		_respawn()


func _respawn() -> void:
	_health.reset()
	rotation = Vector3.ZERO
	position = _base_position
	_body.collision_layer = _body_layer
	visible = true
	alive = true


func _flash() -> void:
	if _visual == null:
		return
	if _flash_mat == null:
		var base: Material = _visual.get_active_material(0)
		_flash_mat = base.duplicate() as StandardMaterial3D
		_flash_mat.emission_enabled = true
		_flash_mat.emission = Color(1.0, 1.0, 1.0)
		_flash_mat.emission_energy_multiplier = 0.0
		_visual.material_override = _flash_mat
	_flash_mat.emission_energy_multiplier = 3.0
	var tween := create_tween()
	tween.tween_property(_flash_mat, "emission_energy_multiplier", 0.0, 0.12)
