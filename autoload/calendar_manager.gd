extends Node

signal calendar_day_started(calendar_day: int, festival_id: String)

const DAYS_PER_MONTH := 30
const MONTHS_PER_YEAR := 12
const DAYS_PER_YEAR := DAYS_PER_MONTH * MONTHS_PER_YEAR
const MONTH_NAMES := ["一月", "二月", "三月", "四月", "五月", "六月", "七月", "八月", "九月", "十月", "十一月", "十二月"]
const SEASON_NAMES := {
	"spring": "春",
	"summer": "夏",
	"autumn": "秋",
	"winter": "冬",
}

func get_day_of_year(day_number: int = -1) -> int:
	var day := TimeSystem.current_day if day_number < 0 else day_number
	return ((maxi(1, day) - 1) % DAYS_PER_YEAR) + 1

func get_year(day_number: int = -1) -> int:
	var day := TimeSystem.current_day if day_number < 0 else day_number
	return 2026 + int((maxi(1, day) - 1) / DAYS_PER_YEAR)

func get_month(day_number: int = -1) -> int:
	return int((get_day_of_year(day_number) - 1) / DAYS_PER_MONTH) + 1

func get_day_of_month(day_number: int = -1) -> int:
	return ((get_day_of_year(day_number) - 1) % DAYS_PER_MONTH) + 1

func get_season_id(day_number: int = -1) -> String:
	var month := get_month(day_number)
	if month >= 3 and month <= 5:
		return "spring"
	if month >= 6 and month <= 8:
		return "summer"
	if month >= 9 and month <= 11:
		return "autumn"
	return "winter"

func get_season_name(day_number: int = -1) -> String:
	return SEASON_NAMES.get(get_season_id(day_number), "春")

func get_date_text(day_number: int = -1) -> String:
	return "%d年%d月%d日" % [get_year(day_number), get_month(day_number), get_day_of_month(day_number)]

func get_calendar_line(day_number: int = -1) -> String:
	return "%s · %s" % [get_season_name(day_number), get_date_text(day_number)]

func get_festival(day_number: int = -1) -> Dictionary:
	return ConfigDB.get_row("calendar", str(get_day_of_year(day_number)))

func is_festival(day_number: int = -1) -> bool:
	return not get_festival(day_number).is_empty()

func get_festival_name(day_number: int = -1) -> String:
	return str(get_festival(day_number).get("name", ""))

func get_business_bonus(day_number: int = -1) -> float:
	return float(get_festival(day_number).get("business_bonus", "0"))

func get_collection_bonus(day_number: int = -1) -> float:
	return float(get_festival(day_number).get("collection_bonus", "0"))

func get_weather_hint(day_number: int = -1) -> String:
	var festival := get_festival(day_number)
	if not festival.is_empty():
		return str(festival.get("weather_hint", ""))
	match get_season_id(day_number):
		"summer":
			return "heat"
		"autumn":
			return "clear"
		"winter":
			return "cool"
		_:
			return "rain"

func get_next_festival_text() -> String:
	var current_doy := get_day_of_year()
	var best_day := DAYS_PER_YEAR + 1
	var best_name := ""
	for day_key in ConfigDB.get_rows("calendar"):
		var day_value := int(day_key)
		if day_value >= current_doy and day_value < best_day:
			best_day = day_value
			best_name = str(ConfigDB.get_row("calendar", day_key).get("name", day_key))
	if best_name.is_empty():
		best_day = 1
		best_name = str(ConfigDB.get_row("calendar", "1").get("name", "元旦"))
	return "下一个节日：%s，还有 %d 天" % [best_name, best_day - current_doy]

func announce_today() -> void:
	var festival := get_festival()
	if festival.is_empty():
		return
	NoticeManager.show_message("今天是%s。%s" % [festival.get("name", ""), festival.get("description", "")], "positive")
	calendar_day_started.emit(get_day_of_year(), str(festival.get("name", "")))