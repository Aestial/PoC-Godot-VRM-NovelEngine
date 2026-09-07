extends TargetDummy
class_name EnemyAgent

## Hostile arena enemy: walks toward the player (straight-line steering on the
## flat floor), deals contact damage on a cooldown, and dies permanently like
## any ShootableTarget (health, plasma, popups, score via TargetDummy).
## Visual variety comes from the per-type scenes; behavior is shared.
##
## Group: "ShootableTargets" (from TargetDummy) + "Enemies" (added here).

@export var chase_speed: float = 2.2
@export var attack_range: float = 1.15
@export var attack_damage: int = 9
@export var attack_interval: float = 0.9
@export var player_path: NodePath

var _player: Node3D
var _attack_cooldown: float = 0.0


func _ready() -> void:
	super._ready()
	add_to_group("Enemies")
	# Arena enemies never respawn after being downed.
	respawn_time = 0.0


func _physics_process(delta: float) -> void:
	if not alive:
		return
	_resolve_player()
	if _attack_cooldown > 0.0:
		_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	if _player == null or not is_instance_valid(_player):
		return

	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist <= 0.001:
		return

	# Face the player (visuals are authored facing -Z).
	rotation.y = atan2(-to_player.x, -to_player.z)

	if dist > attack_range:
		global_position += to_player.normalized() * chase_speed * delta
	elif _attack_cooldown <= 0.0:
		_attack_player()


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	if not player_path.is_empty():
		_player = get_node_or_null(player_path)
	else:
		# Fallback: the first PLAYER-typed ControllableCharacter around.
		for node in get_tree().get_nodes_in_group("ControllableCharacter"):
			if node is NovelCharacter and (node as NovelCharacter).character_type == NovelCharacter.CharacterType.PLAYER:
				_player = node as Node3D
				break


func _attack_player() -> void:
	_attack_cooldown = attack_interval
	var health := _player.get_node_or_null("Health")
	if health and health.has_method("take_damage"):
		health.take_damage(attack_damage, {"position": _player.global_position + Vector3.UP, "attacker": self})
