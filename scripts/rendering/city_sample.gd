class_name CitySample
extends Node3D

var registry := ModelRegistry.new()
var model_nodes: Array[Node3D] = []
var camera: Camera3D


func _ready() -> void:
	CityVisuals.add_lighting(self)
	CityVisuals.add_ground(self, Vector2(28, 56))
	CityVisuals.add_water(self, Vector2(7, 14), Vector2(14, 28))
	_build_sample()
	camera = Camera3D.new()
	camera.name = "SampleCamera"
	camera.position = Vector3(0, 64, 58)
	camera.fov = 52.0
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true


func _build_sample() -> void:
	var placements := {
		"commercial": [
			["commercial_a", -10, -22], ["commercial_low_a", -5, -22],
			["skyscraper_a", -10, -16], ["commercial_c", -5, -16],
			["commercial_low_b", -10, -10], ["parasol", -5, -10]
		],
		"suburban": [
			["house_a", 5, -22], ["house_c", 10, -22],
			["house_b", 5, -16], ["tree", 10, -16],
			["house_d", 5, -10], ["planter", 10, -10]
		],
		"industrial": [
			["industrial_a", -10, 8], ["container", -5, 8],
			["industrial_b", -10, 15], ["tank", -5, 15],
			["industrial_c", -10, 22], ["container", -5, 22]
		],
		"roads": [
			["road_crossroad", 5, 8], ["road_straight", 10, 8],
			["cone", 5, 15], ["traffic_light", 10, 15],
			["road_square", 5, 22], ["dumpster", 10, 22]
		]
	}
	for district_name in placements:
		var district := CityVisuals.add_district(self, district_name)
		for placement in placements[district_name]:
			var variant := "a" if model_nodes.size() % 2 == 0 else "b"
			var model := registry.instantiate(placement[0], variant)
			model.position += Vector3(placement[1], 0, placement[2])
			model.set_meta("district_group", district_name)
			district.add_child(model)
			model_nodes.append(model)
