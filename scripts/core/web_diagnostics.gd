class_name WebDiagnostics
extends RefCounted

const HEARTBEAT_SECONDS: float = 2.0

var enabled: bool = false
var safe_mode: bool = false
var last_swallow: Dictionary = {}
var _heartbeat_elapsed: float = 0.0


func _init() -> void:
	enabled = OS.has_feature("web")
	if enabled:
		var mode = JavaScriptBridge.eval("window.BlackholeDiagnostics && window.BlackholeDiagnostics.safeMode ? 'safe' : 'normal'", true)
		safe_mode = str(mode) == "safe"


func configure_viewport(viewport: Viewport) -> void:
	if not safe_mode:
		return
	viewport.scaling_3d_scale = 0.75
	viewport.msaa_3d = Viewport.MSAA_DISABLED


func apply_safe_scene(root: Node) -> void:
	if not safe_mode:
		return
	for light in root.find_children("*", "DirectionalLight3D", true, false):
		(light as DirectionalLight3D).shadow_enabled = false


func shadows_enabled(root: Node) -> bool:
	for light in root.find_children("*", "DirectionalLight3D", true, false):
		if (light as DirectionalLight3D).shadow_enabled:
			return true
	return false


func heartbeat_due(delta: float) -> bool:
	if not enabled:
		return false
	_heartbeat_elapsed += delta
	if _heartbeat_elapsed < HEARTBEAT_SECONDS:
		return false
	_heartbeat_elapsed = fmod(_heartbeat_elapsed, HEARTBEAT_SECONDS)
	return true


func note_swallow(object_id: int, model_id: String) -> void:
	if enabled:
		last_swallow = {"object_id": object_id, "model_id": model_id}
		publish("swallow", last_swallow)


func publish(type: String, payload: Dictionary) -> void:
	if not enabled:
		return
	var script := "window.BlackholeDiagnostics && window.BlackholeDiagnostics.publish(%s, %s);" % [JSON.stringify(type), JSON.stringify(payload)]
	JavaScriptBridge.eval(script, true)
