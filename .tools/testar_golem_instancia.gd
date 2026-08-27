@tool
extends SceneTree

func _init() -> void:
    _run()

func _run() -> void:
    var BichoScript = load("res://scripts/bicho.gd")
    for t in [0, 3, 4, 5]:
        var b: CharacterBody3D = BichoScript.new()
        b.monster_type = t
        root.add_child(b)
        await process_frame
        print("\n--- Testando Bicho Tipo ", t, " (", b.MONSTROS_CONFIG[t].nome, ") ---")
        print("Modelo no: ", b._modelo)
        if b._modelo:
            print("  modelo pos: ", b._modelo.position, " scale: ", b._modelo.scale, " visible: ", b._modelo.visible)
            for m in b._modelo.find_children("*", "MeshInstance3D", true, false):
                var mi := m as MeshInstance3D
                print("  MeshInstance: ", mi.name, " mesh: ", mi.mesh, " aabb: ", mi.get_aabb(), " visible: ", mi.visible)
            var ap := b._modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
            if ap:
                print("  AnimationPlayer anims: ", ap.get_animation_list(), " current: ", ap.current_animation)
        b.queue_free()
    quit(0)
