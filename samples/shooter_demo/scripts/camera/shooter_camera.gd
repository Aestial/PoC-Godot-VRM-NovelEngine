extends ThirdPersonCamera
class_name ShooterCamera

## Over-the-shoulder camera for the shooter player (derived class keeps the
## base visual-novel camera clean, per the TODO in third_person_camera.gd).
##
## Adds a lateral shoulder offset: the camera rides off-center so the
## character's head never covers the center crosshair / aim ray, and blends
## toward a smaller offset while ADS (recentering over the gun sight).

@export_group("Shoulder")
## Lateral over-shoulder offset in meters along the camera's local X
## (positive = camera-right). 0 disables the shoulder view.
@export var shoulder_offset: float = 0.55
## Shoulder offset while aiming (recenter over the sights).
@export var ads_shoulder_offset: float = 0.3

var _shoulder_current: float = 0.0


func _process(delta: float) -> void:
	_update_shoulder(delta)
	super._process(delta)


func _update_shoulder(delta: float) -> void:
	var target: float = ads_shoulder_offset if _aim_active else shoulder_offset
	if is_equal_approx(_shoulder_current, target):
		return
	_shoulder_current = lerpf(_shoulder_current, target, 1.0 - exp(-delta * ads_blend_speed))


func smooth_move_y(weight) -> void:
	# Same smoothing as the base camera, plus the shoulder offset applied along
	# the pivot's local X so it orbits with the camera yaw.
	var lateral: Vector3 = global_transform.basis * Vector3(_shoulder_current, 0, 0)
	var target := global_position + lateral
	spring_arm.global_position.x = target.x
	spring_arm.global_position.y = lerpf(spring_arm.global_position.y, target.y, weight)
	spring_arm.global_position.z = target.z
