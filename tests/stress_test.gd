extends Node

var failures: Array[String] = []

func _ready() -> void:
	await get_tree().process_frame
	for run_index in range(100):
		_run_month(run_index)
	AudioManager.shutdown()
	await get_tree().process_frame
	if failures.is_empty():
		print("STRESS_TEST_PASS: 100_MONTHS")
		get_tree().quit(0)
	else:
		for failure in failures:
			push_error("STRESS_TEST_FAIL: %s" % failure)
		get_tree().quit(1)

func _run_month(run_index: int) -> void:
	GameState.reset_new_game()
	GameState.money = 320
	WeatherSystem.current_weather_id = ["sunny", "overcast", "rain", "humid", "heat"][run_index % 5]
	for day_index in range(29):
		TimeSystem.minute_of_day = 7 * 60
		GameState.energy = 100.0
		GameState.work_factory_shift()
		if run_index % 4 == 0:
			var found_id := TreasureManager.force_find("street")
			if found_id.is_empty():
				print("STRESS_DEBUG force_find empty run=%d day=%d total=%d collected_before=%d" % [run_index, day_index, CollectionManager.total_collected, run_index])
		GameState.energy = 100.0
		TimeSystem.minute_of_day = 22 * 60
		GameState.sleep_to_next_day()
	if TimeSystem.current_day != 30:
		failures.append("第 %d 轮未进入第 30 天" % run_index)
	if GameState.money < 0:
		failures.append("第 %d 轮出现负现金" % run_index)
	if GameState.rent_arrears != 0:
		failures.append("第 %d 轮正常收入下产生欠租" % run_index)
	if CollectionManager.total_collected == 0:
		failures.append("第 %d 轮摸金彩蛋系统未生效" % run_index)