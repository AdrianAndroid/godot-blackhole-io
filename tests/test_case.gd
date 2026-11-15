class_name TestCase
extends RefCounted

var checks: int = 0
var failures: Array[String] = []
var tree: SceneTree


func run() -> void:
	pass


func expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)


func expect_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	expect(absf(actual - expected) <= tolerance, "%s: actual=%f expected=%f" % [message, actual, expected])
