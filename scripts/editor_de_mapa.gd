extends Node3D
class_name EditorDeMapa
## Editor de mapa que roda DENTRO do jogo publicado, no navegador.
##
## Existe porque o editor do Godot nao roda na maquina do autor e o desenho
## urbano feito por script, as cegas, ja mostrou o seu limite: o olho precisa
## estar no lugar na hora de posicionar.
##
## Uma limitacao que nao da para contornar e precisa estar clara: o site e
## ESTATICO. A pagina publicada nao tem como escrever no repositorio. Entao
## "salvar" grava no armazenamento do proprio navegador (user://, que na web e
## IndexedDB e sobrevive a recarga), e "exportar" copia o JSON para a area de
## transferencia — e esse JSON que vira arquivo do projeto.

const ARQUIVO := "user://mapa_editado.json"

## Distancia maxima do raio de mira ate o chao. Alem disso o clique nao planta:
## e clique no horizonte, e plantar la poria a peca a centenas de metros.
const ALCANCE_DO_CLIQUE := 400.0

@export var jogador: Node3D
@export var camera_do_jogo: Node3D

var ativo := false
var _pecas: Array[Dictionary] = []
var _nos: Array[Node3D] = []
var _selecionada := -1

var _modelo_atual := ""
var _tag_atual := ""
var _pincel := false

var _camera: Camera3D
var _alvo := Vector3.ZERO
var _altura := 60.0
var _arrastando := false

var _painel: CanvasLayer
var _lista: ItemList
var _status: Label


func _ready() -> void:
    _camera = Camera3D.new()
    _camera.current = false
    _camera.far = 600.0
    add_child(_camera)
    _montar_painel()
    carregar()
    _painel.visible = false


# ─────────────────────────────────────────────────────────────────── entrada

func alternar() -> void:
    ativo = not ativo
    _painel.visible = ativo
    _camera.current = ativo
    if ativo:
        _alvo = jogador.global_position if jogador else Vector3.ZERO
        _posicionar_camera()
    elif camera_do_jogo:
        var c := camera_do_jogo.find_child("Camera3D", true, false) as Camera3D
        if c:
            c.current = true
    _atualizar_status()


func _unhandled_input(evento: InputEvent) -> void:
    if not ativo:
        return

    if evento is InputEventMouseButton:
        if evento.button_index == MOUSE_BUTTON_WHEEL_UP:
            _zoom(-0.12)
        elif evento.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _zoom(0.12)
        elif evento.button_index == MOUSE_BUTTON_LEFT:
            _arrastando = evento.pressed
            if evento.pressed:
                _clicar(evento.position)
        elif evento.button_index == MOUSE_BUTTON_RIGHT and evento.pressed:
            _selecionar_em(evento.position)

    elif evento is InputEventMouseMotion:
        if not _arrastando:
            return
        # Botao segurado: arrasta a camera, ou vai plantando se o pincel estiver
        # ligado. Sao os dois gestos que um editor de mapa precisa ter na mao.
        if _pincel and not _modelo_atual.is_empty():
            _plantar_em(evento.position)
        else:
            _mover_camera(evento.relative)

    elif evento is InputEventKey and evento.pressed:
        _tecla(evento.keycode)


func _tecla(codigo: int) -> void:
    if _selecionada < 0:
        if codigo == KEY_ESCAPE:
            _modelo_atual = ""
            _atualizar_status()
        return

    var passo := 0.5
    var peca := _pecas[_selecionada]
    match codigo:
        KEY_A: peca["position"][0] -= passo
        KEY_D: peca["position"][0] += passo
        KEY_W: peca["position"][1] -= passo
        KEY_S: peca["position"][1] += passo
        KEY_Q: peca["rotation"] = fposmod(float(peca["rotation"]) - 15.0, 360.0)
        KEY_E: peca["rotation"] = fposmod(float(peca["rotation"]) + 15.0, 360.0)
        KEY_R: peca["y"] = float(peca.get("y", 0.0)) + 0.25
        KEY_F: peca["y"] = float(peca.get("y", 0.0)) - 0.25
        KEY_EQUAL, KEY_KP_ADD: peca["scale"] = float(peca["scale"]) * 1.1
        KEY_MINUS, KEY_KP_SUBTRACT: peca["scale"] = float(peca["scale"]) / 1.1
        KEY_DELETE, KEY_BACKSPACE:
            _apagar(_selecionada)
            return
        KEY_ESCAPE:
            _selecionada = -1
            _atualizar_status()
            return
        _:
            return
    _refazer(_selecionada)
    _atualizar_status()


# ─────────────────────────────────────────────────────────────────── camera

func _zoom(quanto: float) -> void:
    _altura = clampf(_altura * (1.0 + quanto), 8.0, 220.0)
    _posicionar_camera()


func _mover_camera(delta: Vector2) -> void:
    # A velocidade do arrasto acompanha a altura: alto se percorre o mapa, baixo
    # se ajusta a casa. Um passo fixo serve a uma das duas e atrapalha a outra.
    var escala := _altura * 0.0022
    _alvo += Vector3(-delta.x * escala, 0.0, -delta.y * escala)
    _posicionar_camera()


func _posicionar_camera() -> void:
    # Mesma inclinacao da camera do jogo: editar num angulo e jogar em outro faz
    # o que parecia alinhado sair torto.
    _camera.global_position = _alvo + Vector3(0.0, _altura, _altura * 0.78)
    _camera.look_at(_alvo, Vector3.UP)


func _ponto_no_chao(tela: Vector2) -> Vector3:
    var origem := _camera.project_ray_origin(tela)
    var direcao := _camera.project_ray_normal(tela)
    if direcao.y >= -0.001:
        return Vector3.INF
    var chao := RELEVO.altura(_alvo.x, _alvo.z)
    var distancia := (chao - origem.y) / direcao.y
    if distancia < 0.0 or distancia > ALCANCE_DO_CLIQUE:
        return Vector3.INF
    var ponto := origem + direcao * distancia
    # Segunda passada com a altura do terreno NO PONTO encontrado: em encosta, a
    # primeira mira usa a altura de onde a camera olha e erra metros.
    ponto.y = RELEVO.altura(ponto.x, ponto.z)
    return ponto


const RELEVO := preload("res://scripts/relevo.gd")


# ────────────────────────────────────────────────────────────────── edicao

func _clicar(tela: Vector2) -> void:
    if _modelo_atual.is_empty():
        _selecionar_em(tela)
    else:
        _plantar_em(tela)


func _plantar_em(tela: Vector2) -> void:
    var ponto := _ponto_no_chao(tela)
    if ponto == Vector3.INF:
        return
    # No pincel, nao empilha peca em cima de peca: sem esta distancia minima, um
    # arrasto de meio segundo deixa duzias sobrepostas no mesmo metro.
    if _pincel:
        for peca in _pecas:
            var onde := Vector2(peca["position"][0], peca["position"][1])
            if onde.distance_to(Vector2(ponto.x, ponto.z)) < 2.0:
                return

    _pecas.append({
        "id": "%s_%d" % [_tag_atual, Time.get_ticks_msec()],
        "tag": _tag_atual, "model": _modelo_atual,
        "position": [snappedf(ponto.x, 0.25), snappedf(ponto.z, 0.25)],
        "rotation": 0.0, "scale": 1.0, "y": 0.0,
    })
    _nos.append(null)
    _refazer(_pecas.size() - 1)
    _selecionada = _pecas.size() - 1
    _atualizar_status()


func _selecionar_em(tela: Vector2) -> void:
    var ponto := _ponto_no_chao(tela)
    if ponto == Vector3.INF:
        return
    var melhor := -1
    var menor := 4.0
    for i in _pecas.size():
        var onde := Vector2(_pecas[i]["position"][0], _pecas[i]["position"][1])
        var d := onde.distance_to(Vector2(ponto.x, ponto.z))
        if d < menor:
            menor = d
            melhor = i
    _selecionada = melhor
    _atualizar_status()


func _refazer(indice: int) -> void:
    if _nos[indice] != null and is_instance_valid(_nos[indice]):
        _nos[indice].queue_free()
    var peca := _pecas[indice]
    var kind: Dictionary = World.catalog.get(String(peca["tag"]), {})
    var no := ChunkBuilder._criar(kind, RandomNumberGenerator.new(), String(peca["model"]))
    if no == null:
        return
    var x: float = peca["position"][0]
    var z: float = peca["position"][1]
    no.position = Vector3(x, RELEVO.altura(x, z) + float(peca.get("y", 0.0)), z)
    no.rotation.y = deg_to_rad(float(peca["rotation"]))
    no.scale = Vector3.ONE * float(peca["scale"])
    add_child(no)
    _nos[indice] = no


func _apagar(indice: int) -> void:
    if _nos[indice] != null and is_instance_valid(_nos[indice]):
        _nos[indice].queue_free()
    _pecas.remove_at(indice)
    _nos.remove_at(indice)
    _selecionada = -1
    _atualizar_status()


# ────────────────────────────────────────────────────────── disco e painel

func salvar() -> void:
    var arquivo := FileAccess.open(ARQUIVO, FileAccess.WRITE)
    if arquivo == null:
        _avisar("nao consegui salvar")
        return
    arquivo.store_string(JSON.stringify({"pecas": _pecas}, " "))
    arquivo.close()
    _avisar("salvo — %d pecas" % _pecas.size())


func carregar() -> void:
    if not FileAccess.file_exists(ARQUIVO):
        return
    var arquivo := FileAccess.open(ARQUIVO, FileAccess.READ)
    var dados = JSON.parse_string(arquivo.get_as_text())
    if typeof(dados) != TYPE_DICTIONARY:
        return
    for peca in dados.get("pecas", []):
        _pecas.append(peca)
        _nos.append(null)
        _refazer(_pecas.size() - 1)


func exportar() -> void:
    # Area de transferencia porque o site e estatico: a pagina nao escreve no
    # repositorio, entao o JSON tem de sair por onde o autor consegue leva-lo.
    DisplayServer.clipboard_set(JSON.stringify({"pecas": _pecas}, " "))
    _avisar("JSON copiado — %d pecas" % _pecas.size())


func _montar_painel() -> void:
    _painel = CanvasLayer.new()
    _painel.layer = 20
    add_child(_painel)

    var caixa := VBoxContainer.new()
    caixa.position = Vector2(12, 70)
    caixa.custom_minimum_size = Vector2(230, 0)
    _painel.add_child(caixa)

    _lista = ItemList.new()
    _lista.custom_minimum_size = Vector2(230, 300)
    for tag in World.catalog:
        var kind: Dictionary = World.catalog[tag]
        for caminho in kind.get("models", []) + kind.get("sprites", []):
            _lista.add_item("%s · %s" % [tag, String(caminho).get_file().get_basename()])
            _lista.set_item_metadata(_lista.item_count - 1, [tag, caminho])
    _lista.item_selected.connect(_escolher)
    caixa.add_child(_lista)

    var pincel := CheckBox.new()
    pincel.text = "pincel (arrastar planta varios)"
    pincel.toggled.connect(func(v): _pincel = v)
    caixa.add_child(pincel)

    for rotulo in ["salvar", "exportar JSON", "jogar"]:
        var botao := Button.new()
        botao.text = rotulo
        botao.pressed.connect(_acao.bind(rotulo))
        caixa.add_child(botao)

    _status = Label.new()
    _status.custom_minimum_size = Vector2(230, 90)
    _status.autowrap_mode = TextServer.AUTOWRAP_WORD
    caixa.add_child(_status)


func _escolher(indice: int) -> void:
    var dados: Array = _lista.get_item_metadata(indice)
    _tag_atual = dados[0]
    _modelo_atual = dados[1]
    _selecionada = -1
    _atualizar_status()


func _acao(rotulo: String) -> void:
    match rotulo:
        "salvar": salvar()
        "exportar JSON": exportar()
        "jogar": alternar()


func _avisar(texto: String) -> void:
    _status.text = texto
    await get_tree().create_timer(2.5).timeout
    _atualizar_status()


func _atualizar_status() -> void:
    var linhas := ["%d pecas no mapa" % _pecas.size()]
    if not _modelo_atual.is_empty():
        linhas.append("plantando: " + _modelo_atual.get_file().get_basename())
    if _selecionada >= 0:
        linhas.append("selecionada · WASD move · QE gira · RF altura · +- tamanho · Del apaga")
    else:
        linhas.append("clique planta · botao direito seleciona · arrastar move a camera")
    _status.text = "\n".join(linhas)
