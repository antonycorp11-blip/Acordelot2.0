@tool
extends RefCounted

signal message_received(data: Dictionary)
signal client_connected(is_sse: bool)
signal client_disconnected(is_sse: bool)

var server: TCPServer
var clients: Array[Client] = []
var sse_clients: Array[Client] = []
var outgoing_queue: Array[Dictionary] = []
var current_port: int = 6400

# For synchronous POST responses
var current_post_client: Client = null
var current_post_response = null

class Client:
	extends RefCounted
	var peer: StreamPeerTCP
	var buffer: PackedByteArray
	var request_parsed: bool = false
	var headers: Dictionary = {}
	var method: String = ""
	var path: String = ""
	var content_length: int = 0
	var is_sse: bool = false
	var should_close: bool = false
	
	func _init(p_peer: StreamPeerTCP):
		peer = p_peer
		buffer = PackedByteArray()

func start(port: int) -> Error:
	current_port = port
	server = TCPServer.new()
	# Bind to localhost only for security
	var err = server.listen(port, "127.0.0.1")
	if err != OK:
		return err
	print("MCP Server started on port ", port)
	return OK

func stop():
	if server:
		server.stop()
	for client in clients:
		client.peer.disconnect_from_host()
	clients.clear()
	sse_clients.clear()

func poll():
	if not server: return
	
	while server.is_connection_available():
		var peer = server.take_connection()
		var client = Client.new(peer)
		clients.append(client)
		client_connected.emit(false)
		
	var i = clients.size() - 1
	while i >= 0:
		var client = clients[i]
		client.peer.poll()
		var status = client.peer.get_status()
		
		if status != StreamPeerTCP.STATUS_CONNECTED:
			print("MCP: Client disconnected")
			clients.remove_at(i)
			if client.is_sse:
				print("MCP: SSE Client removed")
				sse_clients.erase(client)
				client_disconnected.emit(true)
			else:
				client_disconnected.emit(false)
			i -= 1
			continue
			
		if client.peer.get_available_bytes() > 0:
			var chunk = client.peer.get_data(client.peer.get_available_bytes())
			if chunk[0] == OK:
				client.buffer.append_array(chunk[1])
				_process_client(client)
		
		if client.should_close:
			client.peer.disconnect_from_host()
			clients.remove_at(i)
			if client.is_sse:
				sse_clients.erase(client)
				client_disconnected.emit(true)
			else:
				client_disconnected.emit(false)
			i -= 1
			continue
				
		i -= 1

func _process_client(client: Client):
	while true:
		if not client.request_parsed:
			# Try to parse headers
			var data_str = client.buffer.get_string_from_utf8()
			var header_end = data_str.find("\r\n\r\n")
			
			if header_end != -1:
				var header_part = data_str.substr(0, header_end)
				var body_part = client.buffer.slice(header_end + 4)
				
				_parse_headers(client, header_part)
				client.buffer = body_part
				client.request_parsed = true
			else:
				break
				
		if client.request_parsed:
			print("MCP Request: ", client.method, " ", client.path)
			if client.method == "GET" and client.path == "/sse":
				_handle_sse_handshake(client)
				break
			elif client.method == "POST" and (client.path == "/message" or client.path == "/sse"):
				if client.buffer.size() >= client.content_length:
					var body = client.buffer.slice(0, client.content_length)
					client.buffer = client.buffer.slice(client.content_length)
					_handle_post_message(client, body)
					
					# Reset for next request on same connection
					client.request_parsed = false
					client.headers = {}
					client.method = ""
					client.path = ""
					client.content_length = 0
					continue
				else:
					break
					
			elif client.method == "OPTIONS":
				_handle_options(client)
				client.should_close = true
				break
			else:
				print("MCP: Unknown request ", client.method, " ", client.path)
				var response = "HTTP/1.1 404 Not Found\r\n\r\n"
				client.peer.put_data(response.to_utf8_buffer())
				client.should_close = true
				break

func _parse_headers(client: Client, header_str: String):
	var lines = header_str.split("\r\n")
	if lines.size() > 0:
		var request_line = lines[0].split(" ")
		if request_line.size() >= 2:
			client.method = request_line[0]
			client.path = request_line[1]
			
	for j in range(1, lines.size()):
		var line = lines[j]
		var parts = line.split(":", true, 1)
		if parts.size() == 2:
			var key = parts[0].strip_edges().to_lower()
			var value = parts[1].strip_edges()
			client.headers[key] = value
			
	if client.headers.has("content-length"):
		client.content_length = client.headers["content-length"].to_int()
	
	if client.headers.has("connection") and client.headers["connection"].to_lower() == "close":
		client.should_close = true

func _handle_sse_handshake(client: Client):
	print("MCP: SSE Handshake")
	client.is_sse = true
	sse_clients.append(client)
	client_connected.emit(true)
	
	var response = "HTTP/1.1 200 OK\r\n" + \
		"Content-Type: text/event-stream\r\n" + \
		"Cache-Control: no-cache\r\n" + \
		"Connection: keep-alive\r\n" + \
		"Access-Control-Allow-Origin: *\r\n" + \
		"\r\n" + \
		"event: endpoint\r\n" + \
		"data: http://127.0.0.1:" + str(current_port) + "/message\r\n\r\n"
		
	client.peer.put_data(response.to_utf8_buffer())
	
	# Flush outgoing queue
	if not outgoing_queue.is_empty():
		print("MCP: Flushing ", outgoing_queue.size(), " queued messages to new SSE client")
		for msg in outgoing_queue:
			_send_sse_data(client, msg)
		outgoing_queue.clear()
	# Don't close connection

func _handle_options(client: Client):
	print("MCP: OPTIONS request")
	var response = "HTTP/1.1 204 No Content\r\n" + \
		"Access-Control-Allow-Origin: *\r\n" + \
		"Access-Control-Allow-Methods: POST, GET, OPTIONS\r\n" + \
		"Access-Control-Allow-Headers: Content-Type\r\n" + \
		"\r\n"
	client.peer.put_data(response.to_utf8_buffer())

func _handle_post_message(client: Client, body: PackedByteArray):
	var json_str = body.get_string_from_utf8()
	print("MCP: POST message received: ", json_str)
	var json = JSON.new()
	var err = json.parse(json_str)
	
	if err == OK:
		var data = json.data
		
		# Setup synchronous capture
		current_post_client = client
		current_post_response = null
		
		message_received.emit(data)
		
		# Check if we captured a response synchronously
		if current_post_response != null:
			print("MCP: Sending synchronous response")
			var resp_json = JSON.stringify(current_post_response)
			var body_bytes = resp_json.to_utf8_buffer()
			
			var connection_header = "keep-alive"
			if client.should_close:
				connection_header = "close"
				
			var response = "HTTP/1.1 200 OK\r\n" + \
				"Content-Type: application/json\r\n" + \
				"Access-Control-Allow-Origin: *\r\n" + \
				"Connection: " + connection_header + "\r\n" + \
				"Content-Length: " + str(body_bytes.size()) + "\r\n" + \
				"\r\n"
			
			var send_err = client.peer.put_data(response.to_utf8_buffer())
			if send_err != OK: print("MCP: Error sending response header: ", send_err)
			
			send_err = client.peer.put_data(body_bytes)
			if send_err != OK: print("MCP: Error sending response body: ", send_err)
		else:
			# Fallback to async/SSE
			var response = "HTTP/1.1 202 Accepted\r\n" + \
				"Access-Control-Allow-Origin: *\r\n" + \
				"\r\n"
			client.peer.put_data(response.to_utf8_buffer())
			
		current_post_client = null
		current_post_response = null
	else:
		print("MCP: Failed to parse JSON: ", json.get_error_message())
		var response = "HTTP/1.1 400 Bad Request\r\n\r\n"
		client.peer.put_data(response.to_utf8_buffer())

func send_message(data: Dictionary):
	# If we are processing a POST and this message is the result, capture it
	if current_post_client != null:
		current_post_response = data
		return

	if sse_clients.is_empty():
		print("MCP: No SSE clients connected, queuing message")
		outgoing_queue.append(data)
		return

	for client in sse_clients:
		if client.peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			_send_sse_data(client, data)

func _send_sse_data(client: Client, data: Dictionary):
	var json_str = JSON.stringify(data)
	var event_str = "event: message\r\ndata: " + json_str + "\r\n\r\n"
	var bytes = event_str.to_utf8_buffer()
	client.peer.put_data(bytes)
