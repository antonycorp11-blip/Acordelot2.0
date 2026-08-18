@tool
extends RefCounted

# MCP Protocol Handler
# Handles JSON-RPC 2.0 messages and MCP specific methods

signal send_message(message: Dictionary)

var tools_manager = null
var _initialized = false
var _client_capabilities = {}

func _init(tools_mgr):
	tools_manager = tools_mgr

func handle_message(data: Dictionary):
	print("MCP Protocol: Received message ", data)
	if not data.has("jsonrpc") or data["jsonrpc"] != "2.0":
		_send_error(data.get("id"), -32600, "Invalid Request")
		return

	if data.has("method"):
		_handle_request(data)
	elif data.has("result") or data.has("error"):
		_handle_response(data)
	else:
		_send_error(data.get("id"), -32600, "Invalid Request")

func _handle_request(request: Dictionary):
	var method = request["method"]
	var params = request.get("params", {})
	var id = request.get("id")

	match method:
		"initialize":
			_handle_initialize(id, params)
		"notifications/initialized":
			_initialized = true
		"ping":
			_send_result(id, {})
		"tools/list":
			if not _check_initialized(id): return
			var tools = tools_manager.list_tools()
			_send_result(id, {"tools": tools})
		"tools/call":
			if not _check_initialized(id): return
			_handle_tool_call(id, params)
		"resources/list":
			if not _check_initialized(id): return
			var resources = tools_manager.list_resources()
			_send_result(id, {"resources": resources})
		"resources/read":
			if not _check_initialized(id): return
			_handle_resource_read(id, params)
		"prompts/list":
			if not _check_initialized(id): return
			_send_result(id, {"prompts": []})
		"logging/setLevel":
			if not _check_initialized(id): return
			_send_result(id, {})
		_:
			if id != null:
				_send_error(id, -32601, "Method not found: " + method)

func _handle_response(response: Dictionary):
	# Handle responses from client if needed
	pass

func _handle_initialize(id, params):
	_client_capabilities = params.get("capabilities", {})
	var protocol_version = params.get("protocolVersion", "2025-11-25")
	
	var result = {
		"protocolVersion": protocol_version,
		"capabilities": {
			"tools": {},
			"resources": {},
			"prompts": {},
			"logging": {}
		},
		"serverInfo": {
			"name": "Godot MCP Server",
			"version": "1.0.0"
		}
	}
	_send_result(id, result)

func _handle_tool_call(id, params):
	var name = params.get("name")
	var args = params.get("arguments", {})
	
	var result = tools_manager.call_tool(name, args)
	
	if result.has("error"):
		# If the tool execution failed logically, we can return a tool error result
		# or a JSON-RPC error. MCP usually expects a result with isError: true for tool failures.
		_send_result(id, {
			"content": [
				{
					"type": "text",
					"text": str(result.error)
				}
			],
			"isError": true
		})
	else:
		_send_result(id, {
			"content": [
				{
					"type": "text",
					"text": JSON.stringify(result)
				}
			]
		})

func _handle_resource_read(id, params):
	var uri = params.get("uri")
	var result = tools_manager.read_resource(uri)
	
	if result.has("error"):
		_send_error(id, -32000, result.error)
	else:
		var content_item = {
			"uri": uri,
			"mimeType": result.mimeType
		}
		if result.has("text"):
			content_item["text"] = result.text
		elif result.has("blob"):
			content_item["blob"] = result.blob
			
		_send_result(id, {
			"contents": [content_item]
		})

func _check_initialized(id) -> bool:
	# Relaxed check: If we have received initialize, we are good to go.
	# Some clients send requests before notifications/initialized.
	# if not _initialized:
	# 	if id != null:
	# 		_send_error(id, -32002, "Server not initialized")
	# 	return false
	return true

func _send_result(id, result):
	if id == null: return
	var msg = {
		"jsonrpc": "2.0",
		"id": id,
		"result": result
	}
	print("MCP Protocol: Sending result ", msg)
	send_message.emit(msg)

func _send_error(id, code, message, data = null):
	if id == null: return
	var error_obj = {
		"code": code,
		"message": message
	}
	if data != null:
		error_obj["data"] = data
		
	var msg = {
		"jsonrpc": "2.0",
		"id": id,
		"error": error_obj
	}
	print("MCP Protocol: Sending error ", msg)
	send_message.emit(msg)

func send_log(level: String, message: String, logger: String = "godot"):
	if not _initialized: return
	
	send_message.emit({
		"jsonrpc": "2.0",
		"method": "notifications/message",
		"params": {
			"level": level,
			"logger": logger,
			"data": message
		}
	})
