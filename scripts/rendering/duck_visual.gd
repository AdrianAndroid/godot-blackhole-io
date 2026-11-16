class_name DuckVisual
extends Node3D


func _init() -> void:
	_part("Body", SphereMesh.new(), Vector3(0, 0.25, 0), Vector3(0.52, 0.42, 0.72), Color("ffd84a"))
	_part("Head", SphereMesh.new(), Vector3(0, 0.55, -0.20), Vector3(0.34, 0.36, 0.34), Color("ffe263"))
	_part("Beak", BoxMesh.new(), Vector3(0, 0.51, -0.43), Vector3(0.24, 0.09, 0.24), Color("ff8b38"))
	_part("WingLeft", SphereMesh.new(), Vector3(-0.25, 0.30, 0.02), Vector3(0.12, 0.25, 0.44), Color("f4b942"))
	_part("WingRight", SphereMesh.new(), Vector3(0.25, 0.30, 0.02), Vector3(0.12, 0.25, 0.44), Color("f4b942"))
	_part("EyeLeft", SphereMesh.new(), Vector3(-0.13, 0.62, -0.34), Vector3.ONE * 0.055, Color("11182b"))
	_part("EyeRight", SphereMesh.new(), Vector3(0.13, 0.62, -0.34), Vector3.ONE * 0.055, Color("11182b"))


func _part(part_name: String, mesh: Mesh, part_position: Vector3, part_scale: Vector3, color: Color) -> void:
	if mesh is SphereMesh:
		mesh.radial_segments = 12
		mesh.rings = 6
		mesh.radius = 0.5
		mesh.height = 1.0
	elif mesh is BoxMesh:
		mesh.size = Vector3.ONE
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = part_position
	instance.scale = part_scale
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	instance.material_override = material
	add_child(instance)
