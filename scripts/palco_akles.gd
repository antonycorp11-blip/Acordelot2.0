extends SubViewportContainer
class_name PalcoAkles
## O AKLES DE VERDADE, NUM PALCO PROPRIO.
##
## Nao e ilustracao: e o `heroi_base.fbx` que anda no mundo. Serve a ficha do
## personagem em tamanho inteiro e o medalhao do inventario em enquadramento de
## rosto, com a mesma peca.
##
## Cada palco tem MUNDO PROPRIO. Sem isso os dois desenhariam no mesmo mundo 3D:
## dois Akles no mesmo ponto e todas as luzes somadas, o que estoura a exposicao
## e deixa o heroi branco, como se estivesse sem textura. Ele nunca esta — e luz
## demais. O viewport tambem so desenha enquanto a pagina esta a mostra.

## Altura em que o modelo e normalizado dentro do palco, em metros.
const ALTURA := 1.75
## Quanto o palco inteiro balanca, em graus para cada lado, e em que ritmo.
const BALANCO := 32.0
const RITMO := 0.5

var _mundo: Node3D
var _palco: SubViewport
var _balancando := false
var _fase := 0.0


func _init(compacto := false) -> void:
    stretch = true
    mouse_filter = Control.MOUSE_FILTER_IGNORE

    _palco = SubViewport.new()
    _palco.own_world_3d = true
    _palco.world_3d = World3D.new()
    _palco.transparent_bg = true
    _palco.render_target_update_mode = SubViewport.UPDATE_DISABLED
    add_child(_palco)

    var ambiente := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0, 0, 0, 0)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("9fb4d8")
    env.ambient_light_energy = 1.30
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_white = 6.0
    ambiente.environment = env
    _palco.add_child(ambiente)

    var chave := DirectionalLight3D.new()
    chave.light_energy = 1.75
    chave.light_color = Color("d8e7ff")
    chave.rotation_degrees = Vector3(-38.0, 148.0, 0.0)
    chave.shadow_enabled = false
    _palco.add_child(chave)

    var frio := OmniLight3D.new()
    frio.light_color = Color("5ab8ff")
    frio.light_energy = 1.6
    frio.omni_range = 6.0
    frio.position = Vector3(-1.6, 1.4, 1.8)
    frio.shadow_enabled = false
    _palco.add_child(frio)

    var quente := OmniLight3D.new()
    quente.light_color = Color("f1cf78")
    quente.light_energy = 1.1
    quente.omni_range = 4.0
    quente.position = Vector3(1.4, 0.9, 1.2)
    quente.shadow_enabled = false
    _palco.add_child(quente)

    _mundo = Node3D.new()
    # DE FRENTE PARA QUEM OLHA. O FBX nasce olhando para -Z e a camera fica em
    # +Z: sem esta meia volta o jogador ve as costas do proprio personagem.
    _mundo.rotation.y = PI
    _palco.add_child(_mundo)

    var cena := load("res://personagem/heroi_base.fbx")
    if cena:
        var corpo: Node3D = (cena as PackedScene).instantiate()
        _mundo.add_child(corpo)
        var caixa := _medir(corpo)
        # O FBX vem do Mixamo em centimetros: o heroi inteiro mede menos de um
        # centesimo em unidades de cena. O limiar tem de caber nisso.
        if caixa.size.y > 0.0001:
            var fator: float = ALTURA / caixa.size.y
            corpo.scale = Vector3.ONE * fator
            corpo.position = Vector3(
                -(caixa.position.x + caixa.size.x * 0.5) * fator,
                -caixa.position.y * fator,
                -(caixa.position.z + caixa.size.z * 0.5) * fator)
        var tocador: AnimationPlayer = corpo.find_child("AnimationPlayer", true, false)
        var biblioteca: AnimationLibrary = load("res://personagem/heroi_anims.res")
        if tocador and biblioteca:
            tocador.add_animation_library("heroi", biblioteca)
            if tocador.has_animation("heroi/parado"):
                tocador.play("heroi/parado")

    # `look_at` trabalha em coordenadas globais e exige o no dentro da arvore.
    # Aqui o palco inteiro ainda esta solto, entao a chamada falharia em
    # silencio e a camera ficaria na orientacao padrao.
    var camera := Camera3D.new()
    camera.current = true
    camera.fov = 26.0 if compacto else 30.0
    _palco.add_child(camera)
    if compacto:
        # O medalhao mira o ROSTO. Mais alto que isto e o alto da cabeca; mais
        # perto e so cabelo.
        camera.look_at_from_position(Vector3(0.0, ALTURA * 0.915, 1.32),
            Vector3(0.0, ALTURA * 0.900, 0.0), Vector3.UP)
    else:
        camera.look_at_from_position(Vector3(0.0, ALTURA * 0.54, 3.0),
            Vector3(0.0, ALTURA * 0.50, 0.0), Vector3.UP)
    # O medalhao NAO gira: retrato que roda mostra a nuca metade do tempo. O
    # palco grande balanca de leve entre um lado e outro, o que deixa a
    # armadura viva sem nunca virar as costas.
    _balancando = not compacto
    set_process(false)


func ligar() -> void:
    _palco.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    set_process(true)


func desligar() -> void:
    _palco.render_target_update_mode = SubViewport.UPDATE_DISABLED
    set_process(false)


func _process(delta: float) -> void:
    if _balancando and _mundo:
        _fase += delta * RITMO
        _mundo.rotation.y = PI + deg_to_rad(BALANCO) * sin(_fase)


func _medir(raiz: Node3D) -> AABB:
    var total := AABB()
    var achou := false
    for malha in raiz.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        var local: AABB = mi.get_aabb()
        var no: Node3D = mi
        while no != null and no != raiz:
            local = no.transform * local
            no = no.get_parent() as Node3D
        total = local if not achou else total.merge(local)
        achou = true
    return total
