@tool
extends RefCounted

var editor_plugin

func _init(plugin):
	editor_plugin = plugin

func list_resources() -> Array:
	# List key project files as resources
	var resources = []
	var dir = DirAccess.open("res://")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir():
				if not file_name.ends_with(".import"):
					resources.append({
						"uri": "res://" + file_name,
						"name": file_name,
						"mimeType": _get_mime_type(file_name)
					})
			file_name = dir.get_next()
	return resources

func _get_mime_type(path: String) -> String:
	var ext = path.get_extension().to_lower()
	match ext:
		"gd": return "application/x-gdscript"
		"tscn": return "text/plain"
		"tres": return "text/plain"
		"json": return "application/json"
		"txt": return "text/plain"
		"md": return "text/markdown"
		"png": return "image/png"
		"jpg", "jpeg": return "image/jpeg"
		"svg": return "image/svg+xml"
		"xml": return "application/xml"
		_: return "application/octet-stream"

func read_resource(uri: String) -> Dictionary:
	if not uri.begins_with("res://"):
		return {"error": "Invalid resource URI: " + uri}
	
	var path = uri
	var mime_type = _get_mime_type(path)
	
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file: " + path}
		
	if mime_type.begins_with("text/") or mime_type == "application/json" or mime_type == "application/x-gdscript" or mime_type == "application/xml":
		return {
			"mimeType": mime_type,
			"text": file.get_as_text()
		}
	else:
		var buffer = file.get_buffer(file.get_length())
		return {
			"mimeType": mime_type,
			"blob": Marshalls.raw_to_base64(buffer)
		}

func list_tools() -> Array:
	return [
		{
			"name": "execute_gdscript",
			"description": "Execute arbitrary GDScript code. Returns the result of the code. The code is wrapped in a function 'run(editor_interface)'. You can access the EditorInterface via 'editor_interface'. You can provide just the body, or the full function definition 'func run(editor_interface): ...'. Note: You cannot define named functions inside the code block, use lambdas instead.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"code": {
						"type": "string",
						"description": "The GDScript code to execute. Should be the body of a function."
					}
				},
				"required": ["code"]
			}
		},
		{
			"name": "get_scene_tree",
			"description": "Get the current scene tree structure.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "get_node_details",
			"description": "Get detailed information about a node.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the node (e.g. '/root/Node3D')"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "get_node_children",
			"description": "Get the list of children for a node.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the node"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "set_node_property",
			"description": "Set a property of a node.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the node"
					},
					"property": {
						"type": "string",
						"description": "Name of the property"
					},
					"value": {
						"type": "string",
						"description": "Value to set (will be parsed as JSON if possible, or string)"
					}
				},
				"required": ["path", "property", "value"]
			}
		},
		{
			"name": "create_node",
			"description": "Create a new node and add it to the scene.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"parent_path": {
						"type": "string",
						"description": "Path to the parent node"
					},
					"class_name": {
						"type": "string",
						"description": "Class name of the node to create (e.g. 'Node3D', 'Sprite2D')"
					},
					"name": {
						"type": "string",
						"description": "Optional name for the new node"
					}
				},
				"required": ["parent_path", "class_name"]
			}
		},
		{
			"name": "delete_node",
			"description": "Delete a node from the scene.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the node to delete"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "reparent_node",
			"description": "Reparent a node to a new parent.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the node to move"
					},
					"new_parent_path": {
						"type": "string",
						"description": "Path to the new parent node"
					},
					"keep_global_transform": {
						"type": "boolean",
						"description": "Whether to keep the global transform (default: true)"
					}
				},
				"required": ["path", "new_parent_path"]
			}
		},
		{
			"name": "instantiate_scene",
			"description": "Instantiate a scene file as a child of a node.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the scene file (e.g. 'res://scenes/player.tscn')"
					},
					"parent_path": {
						"type": "string",
						"description": "Path to the parent node"
					},
					"name": {
						"type": "string",
						"description": "Optional name for the new instance"
					}
				},
				"required": ["path", "parent_path"]
			}
		},
		{
			"name": "connect_signal",
			"description": "Connect a signal from one node to a method on another node.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"from_path": {
						"type": "string",
						"description": "Path to the node emitting the signal"
					},
					"signal_name": {
						"type": "string",
						"description": "Name of the signal"
					},
					"to_path": {
						"type": "string",
						"description": "Path to the node receiving the signal"
					},
					"method_name": {
						"type": "string",
						"description": "Name of the method to call"
					}
				},
				"required": ["from_path", "signal_name", "to_path", "method_name"]
			}
		},
		{
			"name": "get_editor_selection",
			"description": "Get the list of currently selected nodes in the editor.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "get_project_setting",
			"description": "Get a project setting value.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"name": {
						"type": "string",
						"description": "Name of the setting (e.g. 'application/config/name')"
					}
				},
				"required": ["name"]
			}
		},
		{
			"name": "set_project_setting",
			"description": "Set a project setting value.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"name": {
						"type": "string",
						"description": "Name of the setting"
					},
					"value": {
						"type": "string",
						"description": "Value to set"
					}
				},
				"required": ["name", "value"]
			}
		},
		{
			"name": "save_project_settings",
			"description": "Save the project settings to project.godot.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "call_node_method",
			"description": "Call a method on a node.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the node"
					},
					"method": {
						"type": "string",
						"description": "Name of the method to call"
					},
					"args": {
						"type": "array",
						"description": "Array of arguments to pass to the method",
						"items": {}
					}
				},
				"required": ["path", "method"]
			}
		},
		{
			"name": "list_directory",
			"description": "List files and directories in a path.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to list (e.g. 'res://')"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "open_scene",
			"description": "Open a scene file in the editor.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the scene file (e.g. 'res://scenes/main.tscn')"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "read_file",
			"description": "Read the contents of a file.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the file (e.g. 'res://scripts/main.gd')"
					},
					"start_line": {
						"type": "integer",
						"description": "Start line number (1-based, optional)"
					},
					"end_line": {
						"type": "integer",
						"description": "End line number (1-based, optional)"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "create_file",
			"description": "Create a new file with content.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the file"
					},
					"content": {
						"type": "string",
						"description": "Content to write"
					},
					"overwrite": {
						"type": "boolean",
						"description": "Whether to overwrite if file exists (default: false)"
					}
				},
				"required": ["path", "content"]
			}
		},
		{
			"name": "delete_file",
			"description": "Delete a file.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the file"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "rename_file",
			"description": "Rename or move a file.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Current path to the file"
					},
					"new_path": {
						"type": "string",
						"description": "New path for the file"
					}
				},
				"required": ["path", "new_path"]
			}
		},
		{
			"name": "replace_string_in_file",
			"description": "Replace a string in a file with a new string.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the file"
					},
					"old_string": {
						"type": "string",
						"description": "The string to replace"
					},
					"new_string": {
						"type": "string",
						"description": "The new string"
					}
				},
				"required": ["path", "old_string", "new_string"]
			}
		},
		{
			"name": "check_script_errors",
			"description": "Check a GDScript file for syntax errors.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the script file"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "save_scene",
			"description": "Save the currently edited scene.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Optional path to save to. If omitted, saves to existing path."
					}
				}
			}
		},
		{
			"name": "attach_script",
			"description": "Attach a script to a node or a scene file. If the script doesn't exist, it can optionally create it.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the node (e.g. '/root/Node3D') or path to a scene file (e.g. 'res://scenes/my_scene.tscn')"
					},
					"script_path": {
						"type": "string",
						"description": "Path to the script file (e.g. 'res://scripts/my_script.gd')"
					}
				},
				"required": ["path", "script_path"]
			}
		},
		{
			"name": "find_nodes",
			"description": "Find nodes in the current scene by class name or name pattern.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"class_name": {
						"type": "string",
						"description": "Filter by class name (e.g. 'Area2D')"
					},
					"name_pattern": {
						"type": "string",
						"description": "Filter by name pattern (e.g. '*Enemy*')"
					}
				}
			}
		},
		{
			"name": "get_node_signals",
			"description": "Get a list of signals defined for a node.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the node"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "get_node_methods",
			"description": "Get a list of methods defined for a node.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the node"
					}
				},
				"required": ["path"]
			}
		},
		{
			"name": "play_project",
			"description": "Play the project or a specific scene.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"scene_path": {
						"type": "string",
						"description": "Optional path to a specific scene to play. If omitted, plays the main scene."
					}
				}
			}
		},
		{
			"name": "stop_project",
			"description": "Stop the currently running project.",
			"inputSchema": {
				"type": "object",
				"properties": {}
			}
		},
		{
			"name": "create_resource",
			"description": "Create a new resource file.",
			"inputSchema": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to save the resource (e.g. 'res://resources/my_data.tres')"
					},
					"class_name": {
						"type": "string",
						"description": "Class name of the resource (e.g. 'Resource', 'Material')"
					},
					"properties": {
						"type": "object",
						"description": "Initial properties to set"
					}
				},
				"required": ["path", "class_name"]
			}
		}
	]

func call_tool(name: String, args: Dictionary) -> Dictionary:
	match name:
		"execute_gdscript":
			return _execute_gdscript(args.get("code", ""))
		"get_scene_tree":
			return _get_scene_tree()
		"get_node_details":
			return _get_node_details(args.get("path", ""))
		"get_node_children":
			return _get_node_children(args.get("path", ""))
		"set_node_property":
			return _set_node_property(args.get("path", ""), args.get("property", ""), args.get("value", ""))
		"create_node":
			return _create_node(args.get("parent_path", ""), args.get("class_name", ""), args.get("name", ""))
		"delete_node":
			return _delete_node(args.get("path", ""))
		"reparent_node":
			return _reparent_node(args.get("path", ""), args.get("new_parent_path", ""), args.get("keep_global_transform", true))
		"instantiate_scene":
			return _instantiate_scene(args.get("path", ""), args.get("parent_path", ""), args.get("name", ""))
		"connect_signal":
			return _connect_signal(args.get("from_path", ""), args.get("signal_name", ""), args.get("to_path", ""), args.get("method_name", ""))
		"get_editor_selection":
			return _get_editor_selection()
		"get_project_setting":
			return _get_project_setting(args.get("name", ""))
		"set_project_setting":
			return _set_project_setting(args.get("name", ""), args.get("value", ""))
		"save_project_settings":
			return _save_project_settings()
		"call_node_method":
			return _call_node_method(args.get("path", ""), args.get("method", ""), args.get("args", []))
		"list_directory":
			return _list_directory(args.get("path", "res://"))
		"open_scene":
			return _open_scene(args.get("path", ""))
		"read_file":
			return _read_file(args.get("path", ""), args.get("start_line", -1), args.get("end_line", -1))
		"create_file":
			return _create_file(args.get("path", ""), args.get("content", ""), args.get("overwrite", false))
		"write_file":
			return _create_file(args.get("path", ""), args.get("content", ""), true)
		"delete_file":
			return _delete_file(args.get("path", ""))
		"rename_file":
			return _rename_file(args.get("path", ""), args.get("new_path", ""))
		"replace_string_in_file":
			return _replace_string_in_file(args.get("path", ""), args.get("old_string", ""), args.get("new_string", ""))
		"check_script_errors":
			return _check_script_errors(args.get("path", ""))
		"save_scene":
			return _save_scene(args.get("path", ""))
		"attach_script":
			return _attach_script(args.get("path", ""), args.get("script_path", ""))
		"find_nodes":
			return _find_nodes(args.get("class_name", ""), args.get("name_pattern", ""))
		"get_node_signals":
			return _get_node_signals(args.get("path", ""))
		"get_node_methods":
			return _get_node_methods(args.get("path", ""))
		"play_project":
			return _play_project(args.get("scene_path", ""))
		"stop_project":
			return _stop_project()
		"create_resource":
			return _create_resource(args.get("path", ""), args.get("class_name", ""), args.get("properties", {}))
		_:
			return {"error": "Tool not found: " + name}

func _execute_gdscript(code: String) -> Dictionary:
	if code.strip_edges().is_empty():
		return {"error": "Code cannot be empty"}

	var clean_code = code
	
	# Remove comments and whitespace from the beginning to check for func definition
	var lines = clean_code.split("\n")
	var first_code_line_index = -1
	var first_code_line = ""
	
	for i in range(lines.size()):
		var line = lines[i].strip_edges()
		if not line.is_empty() and not line.begins_with("#"):
			first_code_line_index = i
			first_code_line = line
			break
			
	if first_code_line.begins_with("func run"):
		# User provided the function definition. We need to extract the body.
		# We'll take everything after the first code line
		if first_code_line_index != -1 and first_code_line_index + 1 < lines.size():
			var body_lines = lines.slice(first_code_line_index + 1)
			clean_code = "\n".join(body_lines)
			clean_code = _dedent_code(clean_code)
		else:
			clean_code = "" # Empty body
	else:
		clean_code = clean_code.strip_edges()

	var script = GDScript.new()
	script.source_code = "extends RefCounted\nfunc run(editor_interface):\n" + _indent_code(clean_code)
	var err = script.reload()
	
	if err != OK:
		var err_msg = "Failed to compile script: " + str(err)
		if err == ERR_PARSE_ERROR:
			err_msg += " (Parse Error). Check the Godot Output for details."
		return {"error": err_msg}
	
	var instance = script.new()
	if not instance:
		return {"error": "Failed to instantiate script"}
		
	# Capture output?
	# Godot doesn't easily let us capture print() output from a script without redirecting stdout.
	# For now, we rely on the return value.
	
	var result = instance.call("run", editor_plugin.get_editor_interface())
	return {"result": result}

func _indent_code(code: String) -> String:
	var lines = code.split("\n")
	var indented = []
	for line in lines:
		indented.append("\t" + line)
	return "\n".join(indented)

func _dedent_code(code: String) -> String:
	var lines = code.split("\n")
	var min_indent = -1
	var dedented_lines = []
	
	# Find minimum indentation of non-empty lines
	for line in lines:
		if line.strip_edges().is_empty():
			continue
			
		var indent = 0
		for char in line:
			if char == " " or char == "\t":
				indent += 1
			else:
				break
				
		if min_indent == -1 or indent < min_indent:
			min_indent = indent
			
	if min_indent <= 0:
		return code
		
	# Remove indentation
	for line in lines:
		if line.length() >= min_indent:
			dedented_lines.append(line.substr(min_indent))
		else:
			dedented_lines.append(line)
			
	return "\n".join(dedented_lines)

func _get_safe_node(path: String) -> Dictionary:
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return {"error": "No edited scene root found. Please open a scene first."}
	
	var node = root.get_node_or_null(path)
	
	# If not found by absolute path, try relative to the edited scene root
	if not node:
		# If the path starts with /root/SceneName, try to strip it and find relative
		var root_path = str(root.get_path())
		# Note: root path in editor might be /root/@EditorNode@.../SceneName
		
		# Try treating the path as relative to root if it doesn't start with /
		if not path.begins_with("/"):
			node = root.get_node_or_null(path)
			
		# If still not found, and path looks like /root/SceneName/Node, try to match SceneName
		if not node and path.begins_with("/root/"):
			var parts = path.split("/", false)
			if parts.size() >= 2:
				# parts[0] is "root", parts[1] is likely SceneName
				if parts[1] == root.name:
					# Construct relative path from parts[2:]
					if parts.size() == 2:
						node = root
					else:
						var rel_path = "/".join(parts.slice(2))
						node = root.get_node_or_null(rel_path)

	if not node:
		return {"error": "Node not found: " + path}
		
	# Safety check: Ensure node is part of the edited scene
	if node != root and not root.is_ancestor_of(node):
		return {"error": "Access denied: Node '" + path + "' is not part of the currently edited scene."}
		
	return {"node": node}

func _get_scene_tree() -> Dictionary:
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return {"error": "No edited scene root found"}
	
	return {"tree": _node_to_dict(root)}

func _node_to_dict(node: Node) -> Dictionary:
	var children = []
	for child in node.get_children():
		children.append(_node_to_dict(child))
		
	return {
		"name": node.name,
		"class": node.get_class(),
		"path": str(node.get_path()),
		"children": children
	}

func _get_node_details(path: String) -> Dictionary:
	var result = _get_safe_node(path)
	if result.has("error"):
		return result
	var node = result["node"]
		
	var props = {}
	for prop in node.get_property_list():
		var name = prop["name"]
		var val = node.get(name)
		# Filter out complex objects that can't be serialized easily if needed
		if typeof(val) in [TYPE_OBJECT, TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL]:
			props[name] = str(val)
		else:
			props[name] = val
			
	return {
		"name": node.name,
		"class": node.get_class(),
		"path": str(node.get_path()),
		"properties": props
	}

func _get_node_children(path: String) -> Dictionary:
	var result = _get_safe_node(path)
	if result.has("error"):
		return result
	var node = result["node"]
	
	var children = []
	for child in node.get_children():
		children.append({
			"name": child.name,
			"class": child.get_class(),
			"path": str(child.get_path())
		})
		
	return {"children": children}

func _set_node_property(path: String, property: String, value) -> Dictionary:
	if path.begins_with("res://"):
		var tscn_index = path.find(".tscn")
		if tscn_index != -1:
			var scene_path = path.substr(0, tscn_index + 5)
			var node_path = path.substr(tscn_index + 5)
			
			if node_path.begins_with("/"):
				node_path = node_path.substr(1)
			if node_path.is_empty():
				node_path = "."
				
			var open_res = _open_scene(scene_path)
			if open_res.has("error"):
				return open_res
				
			path = node_path

	var result = _get_safe_node(path)
	if result.has("error"):
		return result
	var node = result["node"]
		
	# Try to parse value if it's a string but looks like JSON or Godot Variant
	var parsed_value = value
	if typeof(value) == TYPE_STRING:
		var json = JSON.new()
		if json.parse(value) == OK:
			parsed_value = json.data
		else:
			# Try str_to_var for Godot types (e.g. "Vector3(1, 2, 3)")
			var v = str_to_var(value)
			if v != null:
				parsed_value = v
			
	node.set(property, parsed_value)
	return {"success": true, "new_value": node.get(property)}

func _create_node(parent_path: String, node_class: String, name: String) -> Dictionary:
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return {"error": "No edited scene root found. Please open a scene first."}
		
	var parent
	if parent_path.is_empty() or parent_path == ".":
		parent = root
	else:
		var result = _get_safe_node(parent_path)
		if result.has("error"):
			return result
		parent = result["node"]
		
	if not ClassDB.class_exists(node_class):
		return {"error": "Class does not exist: " + node_class}
		
	var new_node = ClassDB.instantiate(node_class)
	if not new_node:
		return {"error": "Failed to instantiate class: " + node_class}
		
	if not name.is_empty():
		new_node.name = name
		
	parent.add_child(new_node)
	new_node.owner = root # Important for saving the scene
	
	return {
		"success": true,
		"path": str(new_node.get_path()),
		"name": new_node.name
	}

func _delete_node(path: String) -> Dictionary:
	var result = _get_safe_node(path)
	if result.has("error"):
		return result
	var node = result["node"]
	
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if node == root:
		return {"error": "Cannot delete the scene root"}
		
	node.get_parent().remove_child(node)
	node.queue_free()
	
	return {"success": true}

func _read_file(path: String, start_line: int = -1, end_line: int = -1) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file: " + path}
	
	var content = file.get_as_text()
	
	if start_line != -1 or end_line != -1:
		var lines = content.split("\n")
		var start = 0
		var end = lines.size()
		
		if start_line != -1:
			start = max(0, start_line - 1)
			
		if end_line != -1:
			end = min(lines.size(), end_line)
			
		if start >= end:
			return {"content": ""}
			
		var selected_lines = lines.slice(start, end)
		content = "\n".join(selected_lines)
		
	return {"content": content}

func _create_file(path: String, content: String, overwrite: bool) -> Dictionary:
	if not overwrite and FileAccess.file_exists(path):
		return {"error": "File already exists: " + path}

	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return {"error": "Failed to open file for writing: " + path}
	
	file.store_string(content)
	return {"success": true}

func _delete_file(path: String) -> Dictionary:
	var dir = DirAccess.open("res://")
	if not dir:
		return {"error": "Failed to open directory"}
		
	var err = dir.remove(path)
	if err != OK:
		return {"error": "Failed to delete file: " + str(err)}
		
	return {"success": true}

func _rename_file(path: String, new_path: String) -> Dictionary:
	var dir = DirAccess.open("res://")
	if not dir:
		return {"error": "Failed to open directory"}
		
	var err = dir.rename(path, new_path)
	if err != OK:
		return {"error": "Failed to rename file: " + str(err)}
		
	return {"success": true}

func _replace_string_in_file(path: String, old_string: String, new_string: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file: " + path}
		
	var content = file.get_as_text()
	
	if content.find(old_string) == -1:
		return {"error": "old_string not found in file"}
		
	var new_content = content.replace(old_string, new_string)
	
	file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return {"error": "Failed to open file for writing"}
		
	file.store_string(new_content)
	return {"success": true}

func _check_script_errors(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "File not found: " + path}
		
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {"error": "Failed to open file"}
		
	var source = file.get_as_text()
	var script = GDScript.new()
	script.source_code = source
	var err = script.reload()
	
	if err != OK:
		return {
			"valid": false,
			"error_code": err,
			"message": "Script has errors (Error code: " + str(err) + ")"
		}
		
	return {"valid": true}

func _save_scene(path: String) -> Dictionary:
	var editor = editor_plugin.get_editor_interface()
	var scene = editor.get_edited_scene_root()
	if not scene:
		return {"error": "No scene to save"}
		
	var save_path = path
	if save_path.is_empty():
		save_path = scene.scene_file_path
		
	if save_path.is_empty():
		return {"error": "Scene has no path, please specify one"}
		
	var packed_scene = PackedScene.new()
	var err = packed_scene.pack(scene)
	if err != OK:
		return {"error": "Failed to pack scene: " + str(err)}
		
	err = ResourceSaver.save(packed_scene, save_path)
	if err != OK:
		return {"error": "Failed to save scene: " + str(err)}
		
	return {"success": true, "path": save_path}

func _reparent_node(path: String, new_parent_path: String, keep_global_transform: bool) -> Dictionary:
	var result = _get_safe_node(path)
	if result.has("error"):
		return result
	var node = result["node"]
	
	var parent_result = _get_safe_node(new_parent_path)
	if parent_result.has("error"):
		return parent_result
	var new_parent = parent_result["node"]
		
	node.reparent(new_parent, keep_global_transform)
	
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	node.owner = root # Ensure owner is correct after reparenting
	
	return {
		"success": true,
		"new_path": str(node.get_path())
	}

func _instantiate_scene(path: String, parent_path: String, name: String) -> Dictionary:
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return {"error": "No edited scene root found. Please open a scene first."}
		
	var parent
	if parent_path.is_empty() or parent_path == ".":
		parent = root
	else:
		var result = _get_safe_node(parent_path)
		if result.has("error"):
			return result
		parent = result["node"]
		
	if not FileAccess.file_exists(path):
		return {"error": "Scene file does not exist: " + path}
		
	var packed_scene = load(path)
	if not packed_scene or not packed_scene is PackedScene:
		return {"error": "Failed to load scene: " + path}
		
	var instance = packed_scene.instantiate()
	if not instance:
		return {"error": "Failed to instantiate scene"}
		
	if not name.is_empty():
		instance.name = name
		
	parent.add_child(instance)
	instance.owner = root
	
	return {
		"success": true,
		"path": str(instance.get_path()),
		"name": instance.name
	}

func _connect_signal(from_path: String, signal_name: String, to_path: String, method_name: String) -> Dictionary:
	var from_result = _get_safe_node(from_path)
	if from_result.has("error"):
		return from_result
	var from_node = from_result["node"]
	
	var to_result = _get_safe_node(to_path)
	if to_result.has("error"):
		return to_result
	var to_node = to_result["node"]
		
	if not from_node.has_signal(signal_name):
		return {"error": "Signal not found: " + signal_name}
		
	if not to_node.has_method(method_name):
		return {"error": "Method not found: " + method_name}
		
	if from_node.is_connected(signal_name, Callable(to_node, method_name)):
		return {"error": "Signal already connected"}
		
	var err = from_node.connect(signal_name, Callable(to_node, method_name))
	if err != OK:
		return {"error": "Failed to connect signal: " + str(err)}
		
	return {"success": true}

func _get_editor_selection() -> Dictionary:
	var selection = editor_plugin.get_editor_interface().get_selection()
	var nodes = selection.get_selected_nodes()
	var result = []
	
	for node in nodes:
		result.append({
			"name": node.name,
			"path": str(node.get_path()),
			"class": node.get_class()
		})
	
	return {"nodes": result}

func _get_project_setting(name: String) -> Dictionary:
	if not ProjectSettings.has_setting(name):
		return {"error": "Setting not found: " + name}
		
	var value = ProjectSettings.get_setting(name)
	return {"value": value}

func _set_project_setting(name: String, value) -> Dictionary:
	# Try to parse value if it's a string but looks like JSON or Godot Variant
	var parsed_value = value
	if typeof(value) == TYPE_STRING:
		var json = JSON.new()
		if json.parse(value) == OK:
			parsed_value = json.data
		else:
			var v = str_to_var(value)
			if v != null:
				parsed_value = v
	
	ProjectSettings.set_setting(name, parsed_value)
	return {"success": true, "new_value": ProjectSettings.get_setting(name)}

func _save_project_settings() -> Dictionary:
	var err = ProjectSettings.save()
	if err != OK:
		return {"error": "Failed to save project settings: " + str(err)}
	return {"success": true}

func _call_node_method(path: String, method: String, args: Array) -> Dictionary:
	var result = _get_safe_node(path)
	if result.has("error"):
		return result
	var node = result["node"]
		
	if not node.has_method(method):
		return {"error": "Method not found: " + method}
		
	var call_result = node.callv(method, args)
	
	# Handle return value serialization
	if typeof(call_result) in [TYPE_OBJECT, TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL]:
		return {"result": str(call_result)}
	else:
		return {"result": call_result}

func _list_directory(path: String) -> Dictionary:
	var dir = DirAccess.open(path)
	if not dir:
		return {"error": "Failed to open directory: " + path}
		
	dir.list_dir_begin()
	var file_name = dir.get_next()
	var files = []
	var directories = []
	
	while file_name != "":
		if file_name == "." or file_name == "..":
			file_name = dir.get_next()
			continue
			
		if dir.current_is_dir():
			directories.append(file_name)
		else:
			files.append(file_name)
		file_name = dir.get_next()
		
	return {
		"path": path,
		"files": files,
		"directories": directories
	}

func _open_scene(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": "File does not exist: " + path}
		
	editor_plugin.get_editor_interface().open_scene_from_path(path)
	return {"success": true}

func _attach_script_to_file(scene_path: String, script_path: String) -> Dictionary:
	if not FileAccess.file_exists(scene_path):
		return {"error": "Scene file not found: " + scene_path}
		
	var packed_scene = load(scene_path)
	if not packed_scene or not packed_scene is PackedScene:
		return {"error": "Failed to load scene: " + scene_path}
		
	var root_node = packed_scene.instantiate()
	if not root_node:
		return {"error": "Failed to instantiate scene"}
		
	if not FileAccess.file_exists(script_path):
		var file = FileAccess.open(script_path, FileAccess.WRITE)
		if not file:
			root_node.free()
			return {"error": "Script does not exist and could not be created: " + script_path}
		
		var script_content = "extends " + root_node.get_class() + "\n\n# Created by MCP\n"
		file.store_string(script_content)
		file.close()
		
	var script = load(script_path)
	if not script:
		root_node.free()
		return {"error": "Failed to load script: " + script_path}
		
	root_node.set_script(script)
	
	var new_packed_scene = PackedScene.new()
	var err = new_packed_scene.pack(root_node)
	if err != OK:
		root_node.free()
		return {"error": "Failed to pack scene: " + str(err)}
		
	err = ResourceSaver.save(new_packed_scene, scene_path)
	root_node.free()
	
	if err != OK:
		return {"error": "Failed to save scene: " + str(err)}
		
	return {"success": true}

func _attach_script(path: String, script_path: String) -> Dictionary:
	# Check if it looks like a scene file path (either res:// or absolute)
	if path.ends_with(".tscn") or path.ends_with(".scn"):
		return _attach_script_to_file(path, script_path)

	var result = _get_safe_node(path)
	if result.has("error"):
		return result
	var node = result["node"]
	
	if not FileAccess.file_exists(script_path):
		var file = FileAccess.open(script_path, FileAccess.WRITE)
		if not file:
			return {"error": "Script does not exist and could not be created: " + script_path}
		
		var script_content = "extends " + node.get_class() + "\n\n# Created by MCP\n"
		file.store_string(script_content)
		file.close()
		
	var script = load(script_path)
	if not script:
		return {"error": "Failed to load script: " + script_path}
		
	node.set_script(script)
	return {"success": true}

func _find_nodes(class_name_filter: String, name_pattern: String) -> Dictionary:
	var root = editor_plugin.get_editor_interface().get_edited_scene_root()
	if not root:
		return {"error": "No edited scene root found"}
		
	var found = []
	_recursive_find(root, class_name_filter, name_pattern, found)
	
	return {"nodes": found}

func _recursive_find(node: Node, class_name_filter: String, name_pattern: String, result: Array):
	var match_class = true
	if not class_name_filter.is_empty():
		match_class = node.is_class(class_name_filter)
		
	var match_name = true
	if not name_pattern.is_empty():
		match_name = node.name.match(name_pattern)
	
	if match_class and match_name:
		result.append({
			"name": node.name,
			"path": str(node.get_path()),
			"class": node.get_class()
		})
		
	for child in node.get_children():
		_recursive_find(child, class_name_filter, name_pattern, result)

func _get_node_signals(path: String) -> Dictionary:
	var result = _get_safe_node(path)
	if result.has("error"):
		return result
	var node = result["node"]
	
	var signals = []
	for sig in node.get_signal_list():
		signals.append({
			"name": sig["name"],
			"args": sig["args"]
		})
		
	return {"signals": signals}

func _get_node_methods(path: String) -> Dictionary:
	var result = _get_safe_node(path)
	if result.has("error"):
		return result
	var node = result["node"]
	
	var methods = []
	for method in node.get_method_list():
		methods.append({
			"name": method["name"],
			"args": method["args"],
			"return": method["return"]
		})
		
	return {"methods": methods}

func _play_project(scene_path: String) -> Dictionary:
	var interface = editor_plugin.get_editor_interface()
	if scene_path.is_empty():
		interface.play_main_scene()
	else:
		if not FileAccess.file_exists(scene_path):
			return {"error": "Scene file does not exist: " + scene_path}
		interface.play_custom_scene(scene_path)
		
	return {"success": true}

func _stop_project() -> Dictionary:
	var interface = editor_plugin.get_editor_interface()
	interface.stop_playing_scene()
	return {"success": true}

func _create_resource(path: String, class_name_str: String, properties: Dictionary) -> Dictionary:
	if not ClassDB.class_exists(class_name_str):
		return {"error": "Class does not exist: " + class_name_str}
		
	if not ClassDB.is_parent_class(class_name_str, "Resource"):
		return {"error": "Class is not a Resource: " + class_name_str}
		
	var res = ClassDB.instantiate(class_name_str)
	if not res:
		return {"error": "Failed to instantiate resource: " + class_name_str}
		
	for prop in properties:
		res.set(prop, properties[prop])
		
	var err = ResourceSaver.save(res, path)
	if err != OK:
		return {"error": "Failed to save resource: " + str(err)}
		
	return {"success": true, "path": path}
