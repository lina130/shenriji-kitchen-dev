extends Node

## 统一随机数入口。后续收集刷新、事件、经营都可以使用同一套可复现随机源。
var rng := RandomNumberGenerator.new()
var world_seed: int

func _ready() -> void:
	world_seed = int(Time.get_unix_time_from_system())
	rng.seed = world_seed

func begin_new_day(day_number: int) -> void:
	rng.seed = hash("%d:%d" % [world_seed, day_number])

func chance(probability: float) -> bool:
	return rng.randf() < clampf(probability, 0.0, 1.0)

func rand_int(minimum: int, maximum: int) -> int:
	return rng.randi_range(minimum, maximum)

func pick(values: Array):
	if values.is_empty():
		return null
	return values[rng.randi_range(0, values.size() - 1)]

func get_save_data() -> Dictionary:
	return {"world_seed": world_seed}

func restore(data: Dictionary) -> void:
	world_seed = int(data.get("world_seed", world_seed))
	rng.seed = world_seed