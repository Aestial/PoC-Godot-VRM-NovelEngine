extends CanvasLayer
class_name ShooterSettings

## In-game pause + tuning menu (ESC). Lets you adjust camera distance /
## shoulder offset / mouse sensitivity / ADS fov live, then resume.
## All values are applied to the player's ShooterCamera on change.

@export var player_path: NodePath

const PAUSE_ACTION := "pause"

@onready var _panel: Control = $Panel
@onready var _distance_slider: HSlider = $Panel/Margin/VBox/RowDistance/Slider
@onready var _distance_value: Label = $Panel/Margin/VBox/RowDistance/Value
@onready var _shoulder_slider: HSlider = $Panel/Margin/VBox/RowShoulder/Slider
@onready var _shoulder_value: Label = $Panel/Margin/VBox/RowShoulder/Value
@onready var _sens_slider: HSlider = $Panel/Margin/VBox/RowSens/Slider
@onready var _sens_value: Label = $Panel/Margin/VBox/RowSens/Value
@onready var _ads_fov_slider: HSlider = $Panel/Margin/VBox/RowAdsFov/Slider
@onready var _ads_fov_value: Label = $Panel/Margin/VBox/RowAdsFov/Value

var _camera: Node3D
var _was_visible_mouse: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	var player := get_node_or_null(player_path) if not player_path.is_empty() else null
	if player:
		_camera = player.get_node_or_null("ThirdPersonCamera")
	_bind_slider(_distance_slider, _distance_value, "%.1f m", _apply_distance)
	_bind_slider(_shoulder_slider, _shoulder_value, "%.2f", _apply_shoulder)
	_bind_slider(_sens_slider, _sens_value, "%.3f", _apply_sensitivity)
	_bind_slider(_ads_fov_slider, _ads_fov_value, "%.0f fov", _apply_ads_fov)
	var resume: Button = $Panel/Margin/VBox/Resume
	resume.pressed.connect(toggle_pause)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(PAUSE_ACTION):
		toggle_pause()


func toggle_pause() -> void:
	if _panel.visible:
		_resume()
	else:
		_pause()


func _pause() -> void:
	if _camera:
		_sync_sliders_from_camera()
	_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true


func _resume() -> void:
	_panel.visible = false
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _sync_sliders_from_camera() -> void:
	if _camera == null:
		return
	_set_slider(_distance_slider, _distance_value, "%.1f m", _camera.default_camera_distance, 0.6, 6.0)
	_set_slider(_shoulder_slider, _shoulder_value, "%.2f", _camera.shoulder_offset, -1.5, 1.5)
	_set_slider(_sens_slider, _sens_value, "%.3f", _camera.sensitivity_x, 0.0005, 0.02)
	_set_slider(_ads_fov_slider, _ads_fov_value, "%.0f fov", _camera.ads_fov, 30.0, 80.0)


func _bind_slider(slider: HSlider, value_label: Label, fmt: String, applier: Callable) -> void:
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = fmt % v
		applier.call(v))


func _set_slider(slider: HSlider, value_label: Label, fmt: String, value: float, min_v: float, max_v: float) -> void:
	slider.min_value = min_v
	slider.max_value = max_v
	slider.value = value
	value_label.text = fmt % value


func _apply_distance(v: float) -> void:
	if _camera and _camera.has_method("set_camera_distance"):
		_camera.set_camera_distance(v)


func _apply_shoulder(v: float) -> void:
	if _camera:
		_camera.shoulder_offset = v


func _apply_sensitivity(v: float) -> void:
	if _camera:
		_camera.sensitivity_x = v
		_camera.sensitivity_y = v


func _apply_ads_fov(v: float) -> void:
	if _camera:
		_camera.ads_fov = v
