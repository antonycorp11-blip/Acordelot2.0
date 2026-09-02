extends Control
class_name PaginaForjaEscalas

## A forja cromatica oficial. As doze alturas ficam sempre visiveis, sete
## entram na escala escolhida e cada botao toca a frequencia correspondente.
## A escala formada persiste no Progresso e libera seus acordes reais.
const P := preload("res://scripts/ui_proto.gd")
const RodaScript := preload("res://scripts/scale_wheel.gd")

const ORDEM := ["escala_do_maior", "escala_sol_maior", "escala_la_menor"]
const CROMATICAS := ["do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si"]
const ROTULO := {"do":"Dó", "do_sustenido":"Dó♯", "re":"Ré", "re_sustenido":"Ré♯",
    "mi":"Mi", "fa":"Fá", "fa_sustenido":"Fá♯", "sol":"Sol",
    "sol_sustenido":"Sol♯", "la":"Lá", "la_sustenido":"Lá♯", "si":"Si"}
const GRAUS := ["I · Tônica", "II · Supertônica", "III · Mediante",
    "IV · Subdominante", "V · Dominante", "VI · Superdominante", "VII · Sensível"]
const CORES := [Color("f3c868"), Color("55d9ff"), Color("cb79ff")]

var _progresso: Node
var _escolhida := 0
var _lista: VBoxContainer
var _palco: Control
var _direita: VBoxContainer
var _jogando_som := false


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)


func ao_abrir() -> void:
    _pintar()


func _montar() -> void:
    var linha := HBoxContainer.new()
    linha.set_anchors_preset(Control.PRESET_FULL_RECT)
    linha.add_theme_constant_override("separation", 12)
    add_child(linha)

    var biblioteca := P.painel()
    biblioteca.custom_minimum_size.x = 270
    linha.add_child(biblioteca)
    var esquerda := VBoxContainer.new()
    esquerda.add_theme_constant_override("separation", 9)
    biblioteca.add_child(P.recheio(esquerda, 14))
    esquerda.add_child(P.cabecalho("LIVRO DE INTERVALOS", "Escalas", ""))
    _lista = VBoxContainer.new()
    _lista.add_theme_constant_override("separation", 9)
    esquerda.add_child(_lista)
    esquerda.add_child(P.espaco_elastico())
    var mapa := P.rotulo("⌖  LOCAL DO MAPA\nNo HUD apenas para teste. Depois esta tela abre ao interagir com o Observatório Harmônico.", 10, P.MUTED, true)
    mapa.add_theme_stylebox_override("normal", P.estilo(Color("091426"), P.GOLD, 1, 2))
    esquerda.add_child(mapa)

    var painel_palco := P.painel(Color("071325ed"))
    painel_palco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(painel_palco)
    _palco = Control.new()
    _palco.clip_contents = true
    painel_palco.add_child(_palco)

    var resultado := P.painel()
    resultado.custom_minimum_size.x = 315
    linha.add_child(resultado)
    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    resultado.add_child(P.recheio(rol, 14))
    _direita = VBoxContainer.new()
    _direita.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _direita.add_theme_constant_override("separation", 7)
    rol.add_child(_direita)


func _pintar() -> void:
    if _progresso == null or _lista == null:
        return
    for filho in _lista.get_children():
        _lista.remove_child(filho)
        filho.queue_free()
    for indice in range(ORDEM.size()):
        _lista.add_child(_cartao_escala(indice))
    _pintar_palco()
    _pintar_resumo()


func _cartao_escala(indice: int) -> Button:
    var id := String(ORDEM[indice])
    var escala: Dictionary = _progresso.ESCALAS[id]
    var prontas := 0
    for nota in escala["notas"]:
        if _progresso.quantidade("nota_" + String(nota)) > 0:
            prontas += 1
    var b := P.botao("", "item")
    b.custom_minimum_size.y = 118
    b.add_theme_stylebox_override("normal", P.estilo(
        Color(CORES[indice], 0.11) if indice == _escolhida else Color("07101fdc"),
        CORES[indice] if indice == _escolhida else Color("56462f"),
        2 if indice == _escolhida else 1, 2))
    var col := VBoxContainer.new()
    col.mouse_filter = Control.MOUSE_FILTER_IGNORE
    col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
    col.add_child(P.rotulo("◎  " + String(escala["nome"]), 16, P.IVORY))
    col.add_child(P.rotulo(String(escala["intervalos"]), 9, CORES[indice]))
    col.add_child(P.rotulo("%d / 7 notas  ·  %d forjada(s)" % [prontas, _progresso.quantidade(id)], 9, P.MUTED))
    b.add_child(col)
    b.pressed.connect(func():
        _escolhida = indice
        _pintar()
        _tocar_escala(escala["notas"])
    )
    return b


func _pintar_palco() -> void:
    for filho in _palco.get_children():
        _palco.remove_child(filho)
        filho.queue_free()
    var id := String(ORDEM[_escolhida])
    var escala: Dictionary = _progresso.ESCALAS[id]
    var fundo := TextureRect.new()
    fundo.texture = load("res://textures/ui/concepts/scale-forge-concept.png")
    fundo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    fundo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    fundo.modulate = Color(0.65, 0.72, 0.92, 0.38)
    fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    fundo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _palco.add_child(fundo)
    var veu := ColorRect.new()
    veu.color = Color("03081262")
    veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
    veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _palco.add_child(veu)
    var roda: Control = RodaScript.new()
    roda.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 8)
    roda.connect("note_pressed", Callable(self, "_tocar_indice"))
    _palco.add_child(roda)
    var indices: Array = []
    for nota in escala["notas"]:
        indices.append(CROMATICAS.find(String(nota)))
    roda.configure_scale(String(escala["nome"]), indices, String(escala["intervalos"]))


func _pintar_resumo() -> void:
    for filho in _direita.get_children():
        _direita.remove_child(filho)
        filho.queue_free()
    var id := String(ORDEM[_escolhida])
    var escala: Dictionary = _progresso.ESCALAS[id]
    _direita.add_child(P.sobrancelha("PARTITURA DA ESCALA"))
    _direita.add_child(P.rotulo(String(escala["nome"]), 26, P.IVORY))
    _direita.add_child(P.rotulo(String(escala["intervalos"]), 10, CORES[_escolhida]))
    _direita.add_child(P.risco())
    for grau in range(7):
        var nota := String(escala["notas"][grau])
        var quantidade: int = int(_progresso.quantidade("nota_" + nota))
        var linha := HBoxContainer.new()
        linha.custom_minimum_size.y = 38
        var nome := P.rotulo(GRAUS[grau] + "   " + String(ROTULO[nota]), 10,
            P.GREEN if quantidade > 0 else P.MUTED)
        nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        linha.add_child(nome)
        linha.add_child(P.rotulo(("✓ " if quantidade > 0 else "× ") + str(quantidade), 11,
            P.GREEN if quantidade > 0 else Color("ff6b78")))
        _direita.add_child(linha)
    _direita.add_child(P.risco())
    _direita.add_child(P.sobrancelha("RECOMPENSA HARMÔNICA"))
    _direita.add_child(P.rotulo(String(escala["recompensa"]), 13, P.GOLD_BRIGHT, true))
    var forjar := P.botao("◎  Forjar " + String(escala["nome"]), "gold")
    forjar.custom_minimum_size.y = 50
    forjar.disabled = not _progresso.pode_forjar_escala(id)
    forjar.pressed.connect(func():
        if _progresso.forjar_escala(id):
            _tocar_escala(escala["notas"])
            _avisar("Escala forjada", String(escala["nome"]) + " · " + String(escala["recompensa"]))
    )
    _direita.add_child(forjar)
    _direita.add_child(P.sobrancelha("ACORDES LIBERADOS"))
    for acorde_id in _progresso.ACORDES:
        var receita: Dictionary = _progresso.ACORDES[acorde_id]
        if String(receita.get("escala", "")) == id:
            _direita.add_child(_cartao_acorde(String(acorde_id), receita))


func _cartao_acorde(id: String, receita: Dictionary) -> Control:
    var painel := P.painel(Color("0d1b30d9") if _progresso.pode_montar_acorde(id) else Color("07101fbb"))
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 3)
    painel.add_child(col)
    col.add_child(P.rotulo(String(receita["nome"]) + "  " + String(receita["graus"]), 12, P.IVORY))
    col.add_child(P.rotulo(String(receita["efeito"]), 9, P.MUTED, true))
    var b := P.botao("Extrair acorde", "violet")
    b.custom_minimum_size.y = 32
    b.disabled = not _progresso.pode_montar_acorde(id)
    b.pressed.connect(func():
        if _progresso.montar_acorde(id):
            _avisar("Acorde extraído", String(receita["nome"]) + " · " + String(receita["efeito"]))
    )
    col.add_child(b)
    return painel


func _tocar_indice(indice: int) -> void:
    _tocar_frequencias([261.63 * pow(2.0, float(indice) / 12.0)], 0.20)


func _tocar_escala(notas: Array) -> void:
    var frequencias: Array = []
    for nota in notas:
        var indice := CROMATICAS.find(String(nota))
        frequencias.append(261.63 * pow(2.0, float(indice) / 12.0))
    _tocar_frequencias(frequencias, 0.44)


func _tocar_frequencias(frequencias: Array, duracao: float) -> void:
    if _jogando_som:
        return
    _jogando_som = true
    var player := AudioStreamPlayer.new()
    var gerador := AudioStreamGenerator.new()
    gerador.mix_rate = 44100.0
    gerador.buffer_length = duracao + 0.12
    player.stream = gerador
    add_child(player)
    player.play()
    var playback := player.get_stream_playback() as AudioStreamGeneratorPlayback
    var quadros := int(gerador.mix_rate * duracao)
    for quadro in range(quadros):
        var tempo := float(quadro) / gerador.mix_rate
        var envoltoria := pow(1.0 - tempo / duracao, 2.0) * 0.07
        var amostra := 0.0
        for frequencia in frequencias:
            amostra += sin(TAU * float(frequencia) * tempo)
        amostra = amostra / max(1, frequencias.size()) * envoltoria
        playback.push_frame(Vector2(amostra, amostra))
    get_tree().create_timer(duracao + 0.1).timeout.connect(func():
        _jogando_som = false
        player.queue_free()
    )


func _avisar(sobre: String, texto: String) -> void:
    var casca := get_tree().root.find_child("UiShell", true, false)
    if casca and casca.has_method("avisar"):
        casca.avisar(sobre, texto)
