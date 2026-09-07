extends Node3D
class_name VrmColleagueEnemy

## VRM colleague enemy: builds a NovelCharacter at runtime (like ShooterPlayer),
## swaps in a packed VRM colleague (georgino), then drives it zombie-style
## through its own MCC ActionContainer toward the nearest living victim
## (player or the wounded ally).
##
## The inner character leaves the ControllableCharacter group so bullets can
## hit it; its Dialogic interaction layer is disabled and it joins
## ShootableTargets/Enemies to reuse the whole damage/score pipeline.

signal downed(target: Node)

const NOVEL_BASE: PackedScene = preload("res://visual-novel/characters/novel_character_base.tscn")
const GEORGINO_MODEL: PackedScene = preload("res://visual-novel/GJDDM/characters/packed/georgino.scn")
const GEORGINO_DCH: Resource = preload("res://dialogic/characters/Georgino.dch")

@export var points: int = 150
@export var chase_speed: float = 2.4
@export var attack_range: float = 1.35
@export var attack_damage: int = 10
@export var attack_interval: float = 1.0
@export var player_path: NodePath

@onready var _health: Node = $Health

var _inner: NovelCharacter
var alive: bool = true
var _attack_cooldown: float = 0.0
var _target: Node3D = null


func _ready() -> void:
	add_to_group("ShootableTargets")
	add_to_group("Enemies")
	_build_inner()
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)


func _build_inner() -> void:
	_inner = NOVEL_BASE.instantiate() as NovelCharacter
	$Character.add_child(_inner)
	# Same config dance as ShooterPlayer: swap the model + dialogic identity.
	_inner.character_type = NovelCharacter.CharacterType.NPC
	_inner.has_monologue = false
	_inner.dialogic_character = GEORGINO_DCH
	_inner.vrm_scene = GEORGINO_MODEL
	_inner.default_pose_amount = 0.0
	_inner.speed = chase_speed
	# Puppet mode: we drive position + animation directly (robotic walker);
	# disable the inner body's own physics so it never fights the wrapper.
	var grounded := _inner.get_node("MovementManager/GroundedMovement")
	grounded.exit()
	_inner.remove_from_group("ControllableCharacter")
	var area := _inner.collision_shape.get_node_or_null("InteractionArea3D")
	if area:
		(area as Area3D).monitoring = false
		(area as Area3D).monitorable = false
	# NovelCharacter rewires the AnimationPlayer on model swap; make the tree
	# root follow the real model root (name differs per VRM pack).
	call_deferred("_repair_animation_root")
	await get_tree().create_timer(0.1).timeout
	if is_inside_tree():
		_repair_animation_root()


func _repair_animation_root() -> void:
	var tree: AnimationTree = _inner.get_node_or_null("AnimationTree")
	var model_container := _inner.get_node_or_null("CollisionShape3D/ModelContainer")
	if tree == null or model_container == null:
		return
	for child in model_container.get_children():
		if not child.find_children("*", "Skeleton3D", true, false).is_empty():
			tree.root_node = tree.get_path_to(child)
			return


func take_damage(amount: int, hit: Dictionary = {}) -> void:
	_health.take_damage(amount, hit)


func _on_damaged(amount: int, hit: Dictionary) -> void:
	var pos: Vector3 = hit.get("position", global_position + Vector3.UP * 1.2)
	FxBank.popup(get_tree().current_scene, pos, "-%d" % amount, Color(1.0, 0.25, 0.25))
	FxBank.plasma_burst(_inner, pos, hit.get("normal", Vector3.UP), Color(0.85, 0.12, 0.18))


func _on_died(_hit: Dictionary) -> void:
	if not alive:
		return
	alive = false
	downed.emit(self)
	_inner.velocity = Vector3.ZERO
	_inner.collision_layer = 0
	var container := _inner.get_node("ActionContainer")
	container.play_action("MOVE", {"input_direction": Vector3.ZERO})
	container.stop_action("MOVE")
	var sk := get_tree().get_first_node_in_group("ScoreKeeper")
	if sk and sk.has_method("register_down"):
		sk.register_down(self)
	var pos: Vector3 = _inner.global_position + Vector3.UP * 1.4
	FxBank.popup(get_tree().current_scene, pos, "+%d" % points, Color(0.85, 0.8, 0.4))
	# Robotic shutdown: tilt, sink, remove.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_inner, "rotation", Vector3(deg_to_rad(-80.0), 0, 0), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(_inner, "position:y", -0.5, 0.5)
	await tween.finished
	queue_free()


func _physics_process(delta: float) -> void:
	if not alive or _inner == null or not is_instance_valid(_inner):
		return
	_resolve_target()
	if _target == null or not is_instance_valid(_target):
		_set_anim_speed(0.0)
		return
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	var to_target := _target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()
	if dist > attack_range and dist > 0.01:
		var dir_n := to_target.normalized()
		global_position += dir_n * chase_speed * delta
		_inner.collision_shape.rotation.y = atan2(-dir_n.x, -dir_n.z)
		_set_anim_speed(chase_speed)
	else:
		_set_anim_speed(0.0)
		if dist > 0.01 and _attack_cooldown <= 0.0:
			_attack_target()
			_attack_cooldown = attack_interval


## Robot locomotion: mirror the rifle-tree Motion blend values for a walking
## cycle; no CharacterBody physics involved (puppet mode).
func _set_anim_speed(speed: float) -> void:
	var tree := _inner.get_node_or_null("AnimationTree")
	if tree == null:
		return
	tree.set("parameters/LocomotionBlend/blend_amount", 1.0)
	tree.set("parameters/Locomotion/conditions/JUMP", false)
	tree.set("parameters/Locomotion/Motion/blend_position", remap(speed, 0.15, 1.5, 0.0, 1.0))


func _attack_target() -> void:
	var health := _target.get_node_or_null("Health")
	if health and health.has_method("take_damage"):
		health.take_damage(attack_damage, {"position": _target.global_position + Vector3.UP, "attacker": self})


func _resolve_target() -> void:
	var player := get_node_or_null(player_path) if not player_path.is_empty() else null
	var best: Node3D = player as Node3D
	var best_dist := INF
	if best and is_instance_valid(best):
		best_dist = best.global_position.distance_to(_inner.global_position)
	for ally in get_tree().get_nodes_in_group("Allies"):
		var node := ally as Node3D
		if node == null or not is_instance_valid(node):
			continue
		var ally_health := node.get_node_or_null("Health")
		if ally_health and ally_health.get("is_dead"):
			continue
		var d := node.global_position.distance_to(_inner.global_position)
		if d < best_dist:
			best_dist = d
			best = node
	_target = best
