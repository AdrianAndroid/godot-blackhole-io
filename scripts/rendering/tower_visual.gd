class_name TowerVisual
extends Node3D

const VISUAL_HEIGHT: float = 28.0

var blue_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var glow_material: StandardMaterial3D
var beacon: MeshInstance3D
var ground_ring: MeshInstance3D
var animation_time: float = -1.0:
	set(value):
		animation_time = value
		_update_glow()


func _ready() -> void:
	build()


func build() -> void:
	if blue_material != null:
		return
	blue_material = _material(Color("163b9b"), Color("071b58"), 0.20, 0.34)
	dark_material = _material(Color("091d52"), Color("041138"), 0.12, 0.42)
	glow_material = _material(Color("58c9ff"), Color("168dff"), 1.15, 0.24)
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_box("Podium", Vector3(5.6, 0.5, 5.6), Vector3(0, 0.25, 0), dark_material)
	_box("LowerTower", Vector3(4.6, 12.0, 4.6), Vector3(0, 6.5, 0), blue_material)
	_box("MiddleTower", Vector3(3.9, 7.5, 3.9), Vector3(0, 16.25, 0), dark_material)
	_box("Crown", Vector3(3.15, 5.5, 3.15), Vector3(0, 22.75, 0), blue_material)
	_add_strips(4.6, 0.7, 12.1)
	_add_strips(3.9, 12.7, 19.8)
	_add_strips(3.15, 20.2, 25.3)
	for y in [1.0, 3.0, 5.0, 7.0, 9.0, 11.0, 13.0, 15.0, 17.0, 19.0, 21.0, 23.0, 25.0]:
		var width := 4.65 if y < 12.5 else (3.95 if y < 20.0 else 3.2)
		_box("HorizontalLight", Vector3(width, 0.075, 0.09), Vector3(0, y, width * 0.5 + 0.01), glow_material)
		_box("HorizontalLight", Vector3(width, 0.075, 0.09), Vector3(0, y, -width * 0.5 - 0.01), glow_material)
		_box("HorizontalLight", Vector3(0.09, 0.075, width), Vector3(width * 0.5 + 0.01, y, 0), glow_material)
		_box("HorizontalLight", Vector3(0.09, 0.075, width), Vector3(-width * 0.5 - 0.01, y, 0), glow_material)
	var antenna := MeshInstance3D.new()
	antenna.name = "Antenna"
	var antenna_mesh := CylinderMesh.new()
	antenna_mesh.top_radius = 0.055
	antenna_mesh.bottom_radius = 0.12
	antenna_mesh.height = 2.5
	antenna_mesh.radial_segments = 12
	antenna.mesh = antenna_mesh
	antenna.position.y = 26.75
	antenna.material_override = glow_material
	add_child(antenna)
	beacon = MeshInstance3D.new()
	beacon.name = "Beacon"
	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 0.30
	beacon_mesh.height = 0.60
	beacon_mesh.radial_segments = 16
	beacon_mesh.rings = 8
	beacon.mesh = beacon_mesh
	beacon.material_override = glow_material
	beacon.position.y = 28.4
	add_child(beacon)
	ground_ring = MeshInstance3D.new()
	ground_ring.name = "DestinationRing"
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.95
	ring_mesh.outer_radius = 3.20
	ring_mesh.rings = 64
	ring_mesh.ring_segments = 8
	ground_ring.mesh = ring_mesh
	ground_ring.material_override = glow_material
	ground_ring.position.y = 0.08
	ground_ring.scale.y = 0.12
	add_child(ground_ring)
	_update_glow()


func step(delta: float) -> void:
	animation_time = maxf(0.0, animation_time) + delta


func _add_strips(width: float, bottom: float, top: float) -> void:
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box("VerticalLight", Vector3(0.12, top - bottom, 0.12), Vector3(x * width * 0.5, (bottom + top) * 0.5, z * width * 0.5), glow_material)


func _box(part_name: String, size: Vector3, at: Vector3, material: Material) -> void:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = at
	part.material_override = material
	add_child(part)


func _material(color: Color, emission: Color, energy: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.metallic = 0.30
	material.roughness = roughness
	material.emission_enabled = true
	material.emission = emission
	material.emission_energy_multiplier = energy
	return material


func _update_glow() -> void:
	if glow_material == null:
		return
	var time := maxf(0.0, animation_time)
	var pulse := 0.5 + 0.5 * sin(time * 2.4)
	glow_material.emission_energy_multiplier = 0.95 + pulse * 0.45
	beacon.scale = Vector3.ONE * (0.88 + pulse * 0.22)
	ground_ring.scale = Vector3(1.0 + pulse * 0.035, 0.12, 1.0 + pulse * 0.035)
