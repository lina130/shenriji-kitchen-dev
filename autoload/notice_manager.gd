extends Node

signal notice_requested(message: String, tone: String)

var _last_message := ""
var _last_ticks := 0

func show_message(message: String, tone: String = "normal") -> void:
	var now := Time.get_ticks_msec()
	if message == _last_message and now - _last_ticks < 350:
		return
	_last_message = message
	_last_ticks = now
	notice_requested.emit(message, tone)