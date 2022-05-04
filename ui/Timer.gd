extends Node

var enabled := false

var count := 0

onready var whitelabel := $"../WhiteTime"
onready var blacklabel := $"../BlackTime"


func _ready() -> void:
	Events.connect("turn_over", self, "turn_over")


func _process(delta) -> void:
	if !enabled:
		return
	if Globals.team:
		if !whitelabel.set_time(whitelabel.time - delta):
			enabled = false
	else:
		if !blacklabel.set_time(blacklabel.time - delta):
			enabled = false


func turn_over() -> void:
	count += 1
	enabled = count >= 2
