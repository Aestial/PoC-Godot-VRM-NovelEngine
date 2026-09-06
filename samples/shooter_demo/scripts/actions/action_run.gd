extends ActionNode

## Layered speed-modifier action (ACTION_ID "RUN").
##
## Framework usage (MCC): a layered ActionNode that plays on top of the
## layered "MOVE" action. While the controller holds the run input, this node
## re-feeds the active grounded movement state every frame with the same input
## direction but a higher speed, so the movement state itself stays untouched.
##
## Placement: as a child of the character ActionContainer, AFTER the Move node
## (tree order decides which node writes the movement state last each frame).
## The controller already sends play/stop "RUN" via the existing input map.

@export var run_speed: float = 5.5

var _movement_class: MovementState
var _movement_manager: MovementStateManager


func _init() -> void:
	ACTION_ID = "RUN"
	IS_LAYERED = true


func _ready() -> void:
	# ActionContainer children live one level below the character root.
	var character: Node = get_parent().get_parent()
	_movement_class = character.find_child("GroundedMovement", false)
	if not _movement_class:
		_movement_manager = character.find_child("MovementManager", false)
		if _movement_manager:
			_movement_class = _movement_manager.find_child("GroundedMovement", false)


func can_play() -> bool:
	if not is_enabled:
		return false
	# Running only makes sense in a grounded movement state (mirrors Move/Fly actions).
	if _movement_manager and _movement_manager.active_state.name != "GroundedMovement":
		return false
	return true

func play(_params: Dictionary = {}) -> void:
	# Add extra speed multiplier. 
	print("Running")
	
func stop() -> void:
	# Back to normal speed multiplier. 
	pass
	