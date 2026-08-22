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
## Distancia em que ela comeca a ser puxada, e a que conta como coletada.
const RAIO_DO_IMA := 3.4
const RAIO_DE_COLETA := 0.7
const VELOCIDADE_DO_IMA := 7.0
## Some sozinha se ninguem pegar: moeda esquecida no mapa vira lixo de memoria.
const TEMPO_DE_VIDA := 20.0

## Quanto vale. O elite larga uma que vale mais, em vez de largar tres.
@export var valor := 1

var _jogador: Node3D
var _fase := 0.0
var _base_y := 0.0
var _coletada := false


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
    if achou and caixa.size.y > 0.01:
        var fator: float = 0.55 / caixa.size.y
        modelo.scale = Vector3.ONE * fator
        modelo.position.y = -caixa.position.y * fator
    add_child(modelo)

    _base_y = position.y + ALTURA
    position.y = _base_y

    var brilho := OmniLight3D.new()
    brilho.light_color = Color(1.0, 0.86, 0.42)
    brilho.omni_range = 3.0
    brilho.light_energy = 1.6
    brilho.shadow_enabled = false
    add_child(brilho)

    get_tree().create_timer(TEMPO_DE_VIDA).timeout.connect(func():
        if is_instance_valid(self) and not _coletada:
            queue_free())


func _process(delta: float) -> void:
    if _coletada:
        return
    _fase += delta
    rotate_y(delta * 2.2)
    position.y = _base_y + sin(_fase * 2.0) * 0.12

    if _jogador == null or not is_instance_valid(_jogador):
        _jogador = get_tree().get_first_node_in_group("jogador") as Node3D
        if _jogador == null:
            return

    var ate := _jogador.global_position + Vector3.UP * 0.9 - global_position
    var dist := ate.length()
    if dist > RAIO_DO_IMA:
        return
    if dist <= RAIO_DE_COLETA:
        _coletar()
        return
    # Quanto mais perto, mais rapido: da a sensacao de ser sugada.
    global_position += ate.normalized() * VELOCIDADE_DO_IMA * delta * (1.0 + (1.0 - dist / RAIO_DO_IMA))


func _coletar() -> void:
    _coletada = true
    var bolsa := get_tree().get_first_node_in_group("inventario")
    if bolsa == null:
        bolsa = get_node_or_null("/root/ZonedWorld/HUD/InventoryUI")
    if bolsa and "gold_amount" in bolsa:
        bolsa.gold_amount += valor

    var aviso := Label3D.new()
    aviso.text = "+%d" % valor
    aviso.font_size = 26
    aviso.outline_size = 6
    aviso.modulate = Color(1.0, 0.88, 0.45)
    aviso.outline_modulate = Color(0.25, 0.16, 0.0, 1.0)
    aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    aviso.position.y = 0.4
    add_child(aviso)

    var tw := create_tween()
    tw.tween_property(aviso, "position:y", 1.5, 0.5)
    tw.parallel().tween_property(self, "scale", Vector3.ZERO, 0.35)
    tw.parallel().tween_property(aviso, "modulate:a", 0.0, 0.5)
    tw.tween_callback(queue_free)
