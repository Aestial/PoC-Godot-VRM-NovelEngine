extends Object
class_name FxBank

## Lightweight runtime-only FX helpers (no assets required):
## tracer lines, impact flashes and muzzle light pulses.

const TRACER_WIDTH := 0.012
const TRACER_LIFE := 0.07
const IMPACT_LIFE := 0.14


static func tracer(parent: Node, from: Vector3, to: Vector3, color: Color) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var length := from.distance_to(to)
	if length <= 0.01:
		return

	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(TRACER_WIDTH, TRACER_WIDTH, length)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.95)
	mesh.mesh = box
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.global_position = (from + to) * 0.5
	mesh.look_at(to, Vector3.UP)

	var tween := mesh.create_tween()
	tween.tween_method(func(a: float) -> void: mat.albedo_color = Color(color.r, color.g, color.b, a), 0.95, 0.0, TRACER_LIFE)
	tween.tween_callback(mesh.queue_free)


static func impact(parent: Node, position: Vector3, normal: Vector3) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.05
	sphere.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.75, 0.3, 0.95)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.3)
	mesh.mesh = sphere
	mesh.material_override = mat
	parent.add_child(mesh)
	mesh.global_position = position + normal * 0.04
	mesh.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

	var tween := mesh.create_tween()
	tween.set_parallel(true)
	tween.tween_method(func(s: float) -> void: mesh.scale = Vector3.ONE * s, 0.25, 1.0, 0.04)
	tween.tween_method(func(a: float) -> void: mat.albedo_color = Color(1.0, 0.75, 0.3, a), 0.95, 0.0, IMPACT_LIFE)
	tween.tween_callback(mesh.queue_free)


static func muzzle_flash(anchor: Node3D) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.85, 0.5)
	light.light_energy = 6.0
	light.omni_range = 1.2
	anchor.add_child(light)
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.06)
	tween.tween_callback(light.queue_free)
