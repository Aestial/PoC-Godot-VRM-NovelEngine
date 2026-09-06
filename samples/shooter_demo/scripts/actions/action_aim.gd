extends ActionNode
class_name ActionAim

## AIM action (layered): while playing, the character's ThirdPersonCamera
## blends into ADS (fov + spring arm length) and the WeaponRig tightens spread
## and turns the body to face the camera. Controller holds play/stop with RMB.

var _character
var _camera
var _rig


func _init() -> void:
	ACTION_ID = "AIM"
	IS_LAYERED = true


func _ready() -> void:
	_character = get_parent().get_parent()
	_camera = _character.get_node_or_null("ThirdPersonCamera")
	_rig = _character.get_node_or_null("CollisionShape3D/WeaponRig")


func can_play() -> bool:
	if not is_enabled or is_playing:
		return false
	if _character is NovelCharacter and _character.is_busy:
		return false
	return true


func play(_params: Dictionary = {}) -> void:
	if is_playing or not can_play():
		return
	if _camera and _camera.has_method("set_aim_active"):
		_camera.set_aim_active(true)
	if _rig and _rig.has_method("set_aim_active"):
		_rig.set_aim_active(true)
	super.play()


func stop() -> void:
	if not is_playing:
		return
	if _camera and _camera.has_method("set_aim_active"):
		_camera.set_aim_active(false)
	if _rig and _rig.has_method("set_aim_active"):
		_rig.set_aim_active(false)
	super.stop()
