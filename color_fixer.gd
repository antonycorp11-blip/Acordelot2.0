@tool
extends EditorScript

func _run():
    var interface = get_editor_interface()
    var selection = interface.get_selection().get_selected_nodes()
    
    for node in selection:
        _process_node(node)
        
func _process_node(node):
    if node is MeshInstance3D:
        var mesh = node.mesh
        if mesh:
            for i in range(mesh.get_surface_count()):
                var mat = mesh.surface_get_material(i)
                if not mat:
                    mat = StandardMaterial3D.new()
                else:
                    mat = mat.duplicate()
                mat.vertex_color_use_as_albedo = true
                mat.albedo_color = Color(1,1,1,1)
                
                # We apply as an override so it saves in the scene
                node.set_surface_override_material(i, mat)
                print("Cor aplicada em ", node.name)
                
    for child in node.get_children():
        _process_node(child)
