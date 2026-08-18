@tool
extends EditorPlugin

const SETTING_PORT = "addons/godot_mcp/server_port"
const SETTING_AUTO_START = "addons/godot_mcp/auto_start"

var server
var protocol
var tools_mgr
var dock

func _enter_tree():
	print("MCP Plugin: Initializing...")
	# Initialize components
	tools_mgr = preload("res://addons/godot_mcp/tools.gd").new(self)
	protocol = preload("res://addons/godot_mcp/protocol.gd").new(tools_mgr)
	server = preload("res://addons/godot_mcp/server.gd").new()
	
	# Connect signals
	server.message_received.connect(protocol.handle_message)
	protocol.send_message.connect(server.send_message)
	server.client_connected.connect(_on_client_changed)
	server.client_disconnected.connect(_on_client_changed)
	
	# UI
	dock = preload("res://addons/godot_mcp/mcp_panel.tscn").instantiate()
	dock.server_toggled.connect(_on_server_toggled)
	add_control_to_bottom_panel(dock, "MCP")
	
	_load_settings()

func _load_settings():
	var port = 6400
	var auto_start = false
	
	if ProjectSettings.has_setting(SETTING_PORT):
		port = ProjectSettings.get_setting(SETTING_PORT)
	
	if ProjectSettings.has_setting(SETTING_AUTO_START):
		auto_start = ProjectSettings.get_setting(SETTING_AUTO_START)
		
	dock.set_port(port)
	dock.set_auto_start(auto_start)
	
	if auto_start:
		call_deferred("_on_server_toggled", true, port)

func _exit_tree():
	if dock:
		ProjectSettings.set_setting(SETTING_PORT, dock.get_port())
		ProjectSettings.set_setting(SETTING_AUTO_START, dock.is_auto_start())
		ProjectSettings.save()
		
		remove_control_from_bottom_panel(dock)
		dock.free()
		
	if server:
		server.stop()
		server = null
	protocol = null
	tools_mgr = null
	print("Godot MCP: Plugin deactivated")

func _on_server_toggled(active, port):
	if active:
		var err = server.start(port)
		if err != OK:
			printerr("Godot MCP: Failed to start server on port ", port)
			dock.set_server_state(false) # Revert UI
		else:
			print("Godot MCP: Server started on port ", port)
			dock.set_server_state(true)
	else:
		server.stop()
		print("Godot MCP: Server stopped")
		dock.set_server_state(false)

func _on_client_changed(_is_sse):
	if dock and server:
		dock.update_client_count(server.sse_clients.size())

func _process(delta):
	if server:
		server.poll()
