extends Node

signal changed
signal lottery_drawn(prize: int)

var savings := 0
var total_interest := 0
var lottery_spent := 0
var lottery_won := 0
var jackpots := 0

func begin_new_day(_day_number: int) -> void:
	if savings <= 0:
		return
	var rate := ConfigDB.get_number("bank", "daily_interest_rate", 0.0035)
	var interest := maxi(1 if savings > 0 else 0, int(floor(float(savings) * rate)))
	if interest <= 0:
		return
	savings += interest
	total_interest += interest
	NoticeManager.show_message("银行活期利息到账：¥%d" % interest, "positive")
	changed.emit()

func deposit(amount: int) -> bool:
	if amount <= 0:
		return false
	if not GameState.spend(amount):
		return false
	savings += amount
	NoticeManager.show_message("存进银行 ¥%d。" % amount, "positive")
	changed.emit()
	return true

func withdraw(amount: int) -> bool:
	if amount <= 0 or savings < amount:
		NoticeManager.show_message("银行里的钱不够取。", "warning")
		return false
	savings -= amount
	GameState.earn(amount, "从银行取回 ¥%d。" % amount)
	changed.emit()
	return true

func buy_lottery(count: int = 1) -> Dictionary:
	if count <= 0:
		return {"spent": 0, "won": 0}
	var price := int(ConfigDB.get_number("bank", "lottery_ticket_price", 10)) * count
	if not GameState.spend(price):
		return {"spent": 0, "won": 0}
	var won := 0
	for index in range(count):
		var prize := _draw_prize()
		won += prize
		if prize >= 3000:
			jackpots += 1
	lottery_spent += price
	lottery_won += won
	if won > 0:
		GameState.earn(won)
		NoticeManager.show_message("买了 %d 张彩票，中奖 ¥%d。" % [count, won], "positive")
	else:
		NoticeManager.show_message("买了 %d 张彩票，这次没有中奖。" % count, "hint")
	lottery_drawn.emit(won)
	changed.emit()
	return {"spent": price, "won": won}

func get_daily_rate_text() -> String:
	return "每天有少量活期利息"

func get_lottery_summary() -> String:
	return "累计买票 ¥%d，中奖 ¥%d" % [lottery_spent, lottery_won]

func get_save_data() -> Dictionary:
	return {
		"savings": savings,
		"total_interest": total_interest,
		"lottery_spent": lottery_spent,
		"lottery_won": lottery_won,
		"jackpots": jackpots,
	}

func restore(data: Dictionary) -> void:
	savings = maxi(0, int(data.get("savings", 0)))
	total_interest = maxi(0, int(data.get("total_interest", 0)))
	lottery_spent = maxi(0, int(data.get("lottery_spent", 0)))
	lottery_won = maxi(0, int(data.get("lottery_won", 0)))
	jackpots = maxi(0, int(data.get("jackpots", 0)))
	changed.emit()

func reset_new_game() -> void:
	savings = 0
	total_interest = 0
	lottery_spent = 0
	lottery_won = 0
	jackpots = 0
	changed.emit()

func _draw_prize() -> int:
	var roll := RandomManager.rng.randf()
	if roll < 0.001:
		return 3000
	if roll < 0.01:
		return 300
	if roll < 0.05:
		return 50
	if roll < 0.20:
		return 10
	return 0