class_name GrowthManager
extends RefCounted

signal changed(level: int, radius: float)

const MAX_LEVEL: int = 19
const THRESHOLDS: Array[int] = [0, 5, 12, 22, 36, 54, 76, 104, 138, 178, 224, 278, 340, 412, 494, 588, 694, 814, 950]
const RADII: Array[float] = [0.38, 0.50, 0.65, 0.82, 1.00, 1.20, 1.45, 1.70, 1.95, 2.20, 2.50, 2.80, 3.10, 3.40, 3.70, 4.00, 4.30, 4.60, 5.00]

var level: int = 1
var experience: int = 0
var radius: float = RADII[0]


func add_experience(amount: int) -> Array[int]:
	var previous_level := level
	experience += maxi(0, amount)
	for index in range(MAX_LEVEL - 1, -1, -1):
		if experience >= THRESHOLDS[index]:
			level = index + 1
			break
	radius = RADII[level - 1]
	var crossed: Array[int] = []
	for value in range(previous_level + 1, level + 1):
		crossed.append(value)
	if level != previous_level:
		changed.emit(level, radius)
	return crossed


func reset() -> void:
	level = 1
	experience = 0
	radius = RADII[0]
