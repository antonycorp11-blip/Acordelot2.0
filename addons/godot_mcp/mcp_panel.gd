@tool
extends VBoxContainer

signal server_toggled(active: bool, port: int)

var port_spin: SpinBox
var toggle_btn: Button
var status_lbl: Label
var url_display: LineEdit
var client_count_lbl: Label
var auto_start_check: CheckBox

var is_running = false
var sse_client_count = 0

func _ready():
	# Setup UI
	var hbox = HBoxContainer.new()
	add_child(hbox)
	
	var lbl = Label.new()
	lbl.text = "Port:"
	hbox.add_child(lbl)
	
	port_spin = SpinBox.new()
	port_spin.min_value = 1024
	port_spin.max_value = 65535
	port_spin.value = 6400
	port_spin.size_flags_horizontal = SIZE_EXPAND_FILL
	hbox.add_child(port_spin)
	
	toggle_btn = Button.new()
	toggle_btn.text = "Start Server"
	toggle_btn.pressed.connect(_on_toggle_pressed)
	add_child(toggle_btn)
	
	status_lbl = Label.new()
	status_lbl.text = "Status: Stopped"
	add_child(status_lbl)
	
	var url_hbox = HBoxContainer.new()
	add_child(url_hbox)
	
	url_display = LineEdit.new()
	url_display.editable = false
	url_display.placeholder_text = "SSE URL will appear here"
	url_display.size_flags_horizontal = SIZE_EXPAND_FILL
	url_hbox.add_child(url_display)
	
	var copy_btn = Button.new()
	copy_btn.text = "Copy"
	copy_btn.pressed.connect(_on_copy_pressed)
	url_hbox.add_child(copy_btn)
	
	client_count_lbl = Label.new()
	client_count_lbl.text = "Connected Clients: 0"
	add_child(client_count_lbl)
	
	auto_start_check = CheckBox.new()
	auto_start_check.text = "Auto-Start Server"
	add_child(auto_start_check)

func _on_copy_pressed():
	DisplayServer.clipboard_set(url_display.text)

func update_client_count(count: int):
	sse_client_count = count
	client_count_lbl.text = "Connected Clients: " + str(count)

func get_port() -> int:
	return int(port_spin.value)

func set_port(port: int):
	port_spin.value = port

func set_auto_start(enabled: bool):
	auto_start_check.button_pressed = enabled

func is_auto_start() -> bool:
	return auto_start_check.button_pressed

func _on_toggle_pressed():
	# We don't toggle state immediately, we wait for the plugin to confirm success
	# But for the signal, we send the *desired* state
	server_toggled.emit(!is_running, int(port_spin.value))

func set_server_state(running: bool):
	is_running = running
	update_ui()

func update_ui():
	port_spin.editable = !is_running
	if is_running:
		toggle_btn.text = "Stop Server"
		status_lbl.text = "Status: Running"
		status_lbl.modulate = Color.GREEN
		url_display.text = "http://127.0.0.1:%d/sse" % int(port_spin.value)
	else:
		toggle_btn.text = "Start Server"
		status_lbl.text = "Status: Stopped"
		status_lbl.modulate = Color.WHITE
		url_display.text = ""
