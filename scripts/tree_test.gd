extends Node3D
## Bancada para olhar um asset de perto. Julgar arvore pelo mundo inteiro e
## chutar: aqui ela ocupa a tela e o defeito aparece.

func _ready() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.45, 0.52, 0.58)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.66, 0.70, 0.66)
    environment.ambient_light_energy = 0.95
    environment.tonemap_mode = Environment.TONE_MAPPER_ACES
    environment.tonemap_exposure = 1.35
    var holder := WorldEnvironment.new()
    holder.environment = environment
    add_child(holder)

    for node in find_children("*", "MeshInstance3D", true, false):
        node.material_override = load("res://Material_TripoSR.tres")

    await get_tree().create_timer(2.0).timeout
    get_viewport().get_texture().get_image().save_png("user://tree.png")
    print("SHOT arvore")
    get_tree().quit()
