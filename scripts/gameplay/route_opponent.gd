class_name RouteOpponent
extends Swallowable

var actor: HoleActor
var route := PackedVector3Array()
var waypoint: int = 1
var route_speed: float = 2.4


func setup_route(stable_id: int, radius_value: float, color: Color, route_value: PackedVector3Array) -> void:
	kind = "opponent"
	route = route_value
	var representation := Node3D.new()
	actor = HoleActor.new()
	actor.effective_radius = radius_value
	actor.faction_color = color
	actor.move_speed = route_speed
	representation.add_child(actor)
	setup({"id": "opponent_%d" % stable_id, "footprint_radius": radius_value, "xp": 0, "score": 60, "coins": 0}, stable_id, representation)
	if not route.is_empty():
		position = route[0]
		capture_transform()


func step_route(delta: float) -> void:
	if state != State.IDLE or route.size() < 2:
		return
	var target := route[waypoint]
	position = position.move_toward(target, route_speed * delta)
	position.y = 0.0
	if position.distance_to(target) <= 0.001:
		position = target
		waypoint = (waypoint + 1) % route.size()
