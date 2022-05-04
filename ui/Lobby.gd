extends Control

onready var address: LineEdit = $Back/Center/HBox/VBox/Address
onready var buttons = $Back/Center/HBox/VBox/buttons
onready var status_ok = $Back/Center/HBox/VBox/StatusOK
onready var status_fail = $Back/Center/HBox/VBox/StatusFail


func toggle(onoff) -> void:
	visible = onoff
	if onoff:
		for i in get_tree().get_nodes_in_group("control"):
			i.mouse_filter = MOUSE_FILTER_STOP
	else:
		for i in get_tree().get_nodes_in_group("control"):
			i.mouse_filter = MOUSE_FILTER_IGNORE


func _handle_game_over(error, isok) -> void:
	reset_buttons()
	Globals.reset_vars()
	end_game()
	_set_status(error, isok)


func _set_status(text, isok) -> void:  # Simple way to show status.
	if isok:
		status_ok.set_text(text)
		status_fail.set_text("")
		status_ok.visible = len(status_ok.text) > 0
		status_fail.visible = len(status_fail.text) > 0
	else:
		status_ok.set_text("")
		status_fail.set_text(text)
		status_fail.visible = len(status_fail.text) > 0
		status_ok.visible = len(status_ok.text) > 0


func _on_join_pressed() -> void:
	Globals.network.game_code = validate_text()
	Globals.network.send_packet(Globals.network.game_code, Globals.network.HEADERS.joinrequest)
	address.editable = false
	buttons.hide()


func _on_HostButton_pressed() -> void:
	Globals.network.game_code = validate_text()
	Globals.network.send_packet(Globals.network.game_code, Globals.network.HEADERS.hostrequest)
	address.editable = false
	buttons.hide()


func validate_text(text = address.get_text()) -> String:
	var pos = address.caret_position
	text = text.strip_edges()
	text = text.replace(" ", "_")
	address.text = text
	address.caret_position = pos
	return text


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	Events.connect("go_back", self, "end_game")
	if !is_instance_valid(Globals.network):
		Globals.network = Network.new()
		Globals.network.connect("move_data", self, "_on_data")
		Globals.network.connect("join_result", self, "_on_join_result")
		Globals.network.connect("host_result", self, "_on_host_result")
		Globals.network.connect("game_over", self, "_handle_game_over")
		Globals.network.connect("start_game", self, "_start_game")
		add_child(Globals.network)


func end_game() -> void:
	if get_tree().get_root().has_node("World"):
		get_tree().get_root().get_node("World").queue_free()
	toggle(true)


func create_world() -> void:
	var world = load("res://World.tscn").instance()
	get_tree().get_root().add_child(world)
	toggle(false)


func _start_game() -> void:
	create_world()


func _on_join_result(accepted: String) -> void:
	Globals.team = false
	if accepted == "Y":
		_set_status("Joined!", true)
		Globals.network.send_packet("", Globals.network.HEADERS.startgame)
	else:
		_set_status(accepted, false)
		reset_buttons()


func reset_buttons() -> void:
	buttons.show()
	address.editable = true


func _on_host_result(accepted: String) -> void:
	Globals.team = true
	if accepted == "Y":
		_set_status("Hosted!", true)
	else:
		_set_status(accepted, false)
		reset_buttons()


func add_turn() -> void:
	Events.emit_signal("just_before_turn_over")
	Globals.add_turn()
	Globals.turn = not Globals.turn
	Events.emit_signal("turn_over")


func _on_data(data: Dictionary) -> void:
	Globals.fullmove = data["fullmove"]
	Globals.turn = data["turn"]
	Globals.halfmove = data["halfmove"]
	match data["movetype"]:
		Network.MOVEHEADERS.passant:
			# en passant
			var end_pos = Vector2(dict2vec(data["positions"][1]))
			var start_piece = Piece.at_pos(Vector2(dict2vec(data["positions"][0])))
			Piece.at_pos(Vector2(dict2vec(data["positions"][2]))).took()  # kill the unfortunate
			start_piece.passant(end_pos)
		Network.MOVEHEADERS.take:
			var start_piece = Piece.at_pos(Vector2(dict2vec(data["positions"][0])))
			var end_piece = Piece.at_pos(Vector2(dict2vec(data["positions"][1])))
			start_piece.take(end_piece)
		Network.MOVEHEADERS.move:
			var end_pos = Vector2(dict2vec(data["positions"][1]))
			var start_piece = Piece.at_pos(Vector2(dict2vec(data["positions"][0])))
			start_piece.moveto(end_pos)
		Network.MOVEHEADERS.castle:
			var king = Piece.at_pos(dict2vec(data["positions"]["king"]))
			var rook = Piece.at_pos(dict2vec(data["positions"]["rook"]))
			rook.moveto(dict2vec(data["positions"]["rookdestination"]), true, false, true)
			Utils.add_move(king.castle(dict2vec(data["positions"]["kingdestination"])))


func dict2vec(dict: Dictionary) -> Vector2:
	return Vector2(dict["x"], dict["y"])


func _notification(what: int) -> void:
	if what == MainLoop.NOTIFICATION_WM_QUIT_REQUEST or what == MainLoop.NOTIFICATION_WM_GO_BACK_REQUEST:
		Globals.network.send_packet(Globals.network.game_code, Globals.network.HEADERS.stopgame)
		yield(get_tree(), "idle_frame")  # wait for the packet to send
		get_tree().quit()


func _on_Address_text_entered(new_text: String):
	validate_text(new_text)
	Globals.network.game_code = new_text
