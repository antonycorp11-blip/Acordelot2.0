extends Node3D
class_name MoedaPve
## A clave que o Shiker larga ao morrer — a moeda de PVE do jogo.
##
## Gira, flutua e vai sozinha para o jogador quando ele chega perto. O ima e de
## proposito: num jogo de toque, pedir que o dedo acerte um objeto de meio metro
## no chao depois da briga e trabalho sem graca, e todo ARPG moderno resolve
## assim.
##
## Uma por morte, e nao um punhado. O modelo tem cinquenta mil triangulos — tres
## delas no chao custam mais que o bicho que as largou. Se um dia virar chuva de
## moeda, o caminho e uma malha simplificada, nao mais copias desta.

const CENA := preload("res://models/clave_moeda.glb")
const ALTURA := 0.85
## Distancia em que a coleta automatica comeca.
const RAIO_DO_IMA := 3.4
## Some sozinha se ninguem pegar: moeda esquecida no mapa vira lixo de memoria.
const TEMPO_DE_VIDA := 20.0

## Quanto vale. O elite larga uma que vale mais, em vez de largar tres.
@export var valor := 1

var _jogador: Node3D
var _fase := 0.0
var _base_y := 0.0
var _coletada := false
var _halo: MeshInstance3D = null


func _ready() -> void:
    add_to_group("moeda_pve")
    _fase = randf() * TAU

    var modelo := CENA.instantiate()
    # Ao tamanho de moeda: o arquivo vem com quase um metro de altura.
    var caixa := AABB()
    var achou := false
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        var local: AABB = mi.transform * mi.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        # Cinquenta mil triangulos nao precisam ser desenhados de longe.
        mi.visibility_range_end = 42.0
        mi.visibility_range_end_margin = 6.0
        # A clave ACENDE por dentro.
        #
        # O modelo veio com a cor de metal escurecido e, no chao de dia, sumia
        # na grama. Emissao dourada na propria pele resolve sem depender de luz
        # nenhuma: ela passa a ser a coisa mais clara do gramado, que e o que
        # uma moeda largada no chao precisa ser.
        for si in range(mi.mesh.get_surface_count() if mi.mesh else 0):
            var base := mi.get_active_material(si)
            var aceso: StandardMaterial3D = (base as StandardMaterial3D).duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()
            aceso.emission_enabled = true
            aceso.emission = Color(1.0, 0.82, 0.35)
            aceso.emission_energy_multiplier = 0.9
            aceso.metallic = 0.2
            aceso.roughness = 0.35
            mi.set_surface_override_material(si, aceso)
    if achou and caixa.size.y > 0.01:
        var fator: float = 0.55 / caixa.size.y
        modelo.scale = Vector3.ONE * fator
        modelo.position.y = -caixa.position.y * fator
    add_child(modelo)

    assentar()

    # E o halo em volta: um cartao aditivo que a camera sempre ve de frente. E
    # ele que faz a clave ser notada de longe, quando o modelo em si e so um
    # risco dourado de meio metro no meio do mato.
    var halo := MeshInstance3D.new()
    halo.name = "Halo"
    var quadro := QuadMesh.new()
    quadro.size = Vector2(1.5, 1.5)
    var brilho_mat := StandardMaterial3D.new()
    brilho_mat.albedo_texture = preload("res://textures/brilho_poste.png")
    brilho_mat.albedo_color = Color(0.85, 0.62, 0.22)
    brilho_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    brilho_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    brilho_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    brilho_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    brilho_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    quadro.material = brilho_mat
    halo.mesh = quadro
    halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(halo)
    _halo = halo

    # Uma luz por MORTE, nao por moeda: tres claves juntas acendiam tres luzes
    # pontuais no mesmo metro quadrado, e a terceira nao acrescenta nada que a
    # primeira ja nao mostre.
    if get_tree().get_nodes_in_group("moeda_pve").size() <= 1:
        var brilho := OmniLight3D.new()
        brilho.light_color = Color(1.0, 0.86, 0.42)
        brilho.omni_range = 3.2
        brilho.light_energy = 1.7
        brilho.shadow_enabled = false
        add_child(brilho)

    get_tree().create_timer(TEMPO_DE_VIDA).timeout.connect(func():
        if is_instance_valid(self) and not _coletada:
            queue_free())


## Fixa a altura em que a clave vai flutuar, a partir de onde ela esta AGORA.
##
## Antes isso era feito uma unica vez dentro de `_ready`, que roda no instante
## do `add_child` — ou seja, antes de quem largou a moeda dizer onde ela cai. O
## resultado era a moeda flutuando 0,85 m acima da ORIGEM DA REGIAO em vez de
## acima do chao onde o bicho morreu: em terreno rebaixado, isso e a moeda no
## ceu. Quem posiciona chama isto depois de posicionar.
func assentar() -> void:
    _base_y = position.y + ALTURA
    position.y = _base_y


func _process(delta: float) -> void:
    if _coletada:
        return
    _fase += delta
    rotate_y(delta * 2.2)
    position.y = _base_y + sin(_fase * 2.0) * 0.12
    # O halo pulsa devagar: brilho parado vira mancha, brilho que respira vira
    # coisa que pede para ser pega.
    if _halo:
        var pulso: float = 0.85 + sin(_fase * 3.0) * 0.15
        _halo.scale = Vector3.ONE * pulso
        # Contragira, para o cartao nao rodar junto com a moeda.
        _halo.rotation.y = -rotation.y

    if _jogador == null or not is_instance_valid(_jogador):
        # O personagem zonado pertence ao grupo "player". Procurar apenas por
        # "jogador" fazia a clave flutuar ate expirar sem nunca ser capturada.
        _jogador = get_tree().get_first_node_in_group("player") as Node3D
        if _jogador == null:
            _jogador = get_tree().get_first_node_in_group("jogador") as Node3D
        if _jogador == null:
            return

    var alvo := _jogador.global_position + Vector3.UP * 0.75
    var ate := alvo - global_position
    var dist := ate.length()
    if dist > RAIO_DO_IMA:
        return
    # Credita imediatamente e faz um unico voo curto ate a posicao que o heroi
    # ocupava neste instante. Antes a moeda perseguia um alvo em movimento e
    # ainda tinha o Y recolocado pela flutuacao: grudava no corpo, orbitava e
    # so depois conseguia cruzar o raio de coleta.
    _coletar(alvo)


func _coletar(alvo_visual := Vector3.ZERO) -> void:
    _coletada = true
    set_process(false)
    var progresso := get_node_or_null("/root/Progresso")
    if progresso:
        progresso.adicionar_recurso("claves", valor)
    else:
        var bolsa := get_tree().get_first_node_in_group("inventario")
        if bolsa == null:
            bolsa = get_node_or_null("/root/ZonedWorld/HUD/InventoryUI")
        if bolsa and bolsa.has_method("receber_claves"):
            bolsa.receber_claves(valor)

    var aviso := Label3D.new()
    aviso.text = "+%d" % valor
    aviso.font_size = 26
    aviso.outline_size = 6
    aviso.modulate = Color(1.0, 0.88, 0.45)
    aviso.outline_modulate = Color(0.25, 0.16, 0.0, 1.0)
    aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    aviso.top_level = true
    add_child(aviso)
    aviso.global_position = global_position + Vector3.UP * 0.4

    var tw := create_tween()
    if alvo_visual != Vector3.ZERO:
        tw.tween_property(self, "global_position", alvo_visual, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
    tw.parallel().tween_property(self, "scale", Vector3.ZERO, 0.18)
    tw.parallel().tween_property(aviso, "global_position:y", aviso.global_position.y + 1.1, 0.48)
    tw.parallel().tween_property(aviso, "modulate:a", 0.0, 0.48)
    tw.tween_callback(queue_free)
