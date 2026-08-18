extends Node3D
## Bancada do personagem: frente e lado, para conferir a pose antes do Mixamo.
## O auto-rigger exige braco e perna SEPARADOS do corpo — se estiverem colados,
## ele erra o esqueleto ou recusa, e isso se ve numa olhada.

func _ready() -> void:
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.16, 0.18, 0.22)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.75, 0.77, 0.82)
    environment.ambient_light_energy = 1.2
    var holder := WorldEnvironment.new()
    holder.environment = environment
    add_child(holder)

    var heroi: Node3D = $Heroi
    var camera: Camera3D = $Camera3D

    # Enquadra pela caixa da malha: a origem do modelo nao e o centro dele, e
    # chutar a camera deixou o personagem no canto da tela.
    var bounds := AABB()
    var primeiro := true
    for node in heroi.find_children("*", "MeshInstance3D", true, false):
        var caixa: AABB = node.global_transform * node.get_aabb()
        bounds = caixa if primeiro else bounds.merge(caixa)
        primeiro = false

    var centro := bounds.get_center()
    var altura: float = maxf(bounds.size.y, 0.001)
    var distancia := altura * 1.6

    for tomada in [["frente", 0.0], ["lado", PI * 0.5]]:
        heroi.rotation.y = float(tomada[1])
        camera.global_position = centro + Vector3(0.0, 0.0, distancia)
        camera.look_at(centro)
        # Alguns quadros: o primeiro sai preto porque nada foi desenhado ainda.
        for espera in 4:
            await get_tree().process_frame
        get_viewport().get_texture().get_image().save_png(
            "user://char_%s.png" % tomada[0])

    print("SHOT personagem altura=", altura, " centro=", centro)
    get_tree().quit()
