extends Control
class_name PaginaPersonagem
## Ficha do Akles: nivel, poder, atributos e as duas acoes de progressao.
const T := preload("res://scripts/ui_tema.gd")

const NOMES := {"forca": "Força", "destreza": "Destreza", "vitalidade": "Vitalidade",
    "ressonancia": "Ressonância", "percepcao": "Percepção"}

var _progresso: Node
var _nivel: Label
var _xp: Label
var _barra: ProgressBar
var _pontos: Label
var _poder: Label
var _linhas: Dictionary = {}
var _acao: Button
var _stats: VBoxContainer

func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)

func ao_abrir() -> void: _pintar()

func _montar() -> void:
    var linha := HBoxContainer.new()
    linha.set_anchors_preset(Control.PRESET_FULL_RECT)
    linha.add_theme_constant_override("separation", 18)
    add_child(linha)

    # --------------------------------------------------- coluna do heroi
    var esq := T.coluna(18)
    esq.custom_minimum_size.x = 360
    linha.add_child(esq)
    # SEM ROLAGEM: a ficha inteira cabe deitada.
    #
    # A tela e larga, entao o que sobrava em altura foi para os lados — retrato
    # e progresso a esquerda, atributos no meio, combate a direita. Rolar dentro
    # de uma ficha de personagem e sinal de layout em pe espremido no deitado.
    var ce := VBoxContainer.new()
    ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ce.add_theme_constant_override("separation", 6)
    esq.add_child(ce)

    var retrato := PanelContainer.new()
    retrato.custom_minimum_size = Vector2(0, 150)
    retrato.add_theme_stylebox_override("panel", T.painel(T.NAVY_CLARO, T.OURO_ARO, 10, 2, 8))
    ce.add_child(retrato)
    var folha := load("res://textures/dialogo/akles_corpo.png") as Texture2D
    if folha:
        var corte := AtlasTexture.new()
        corte.atlas = folha
        corte.region = Rect2(folha.get_width() * 0.30, 0.0,
            folha.get_width() * 0.40, folha.get_height() * 0.42)
        var img := TextureRect.new()
        img.texture = corte
        img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        retrato.add_child(img)

    ce.add_child(T.rotulo("Akles", T.NOME_ITEM, T.OURO_FORTE))
    _nivel = T.rotulo("", T.TITULO_SECAO, T.TEXTO)
    ce.add_child(_nivel)
    _barra = ProgressBar.new()
    _barra.custom_minimum_size.y = 14
    _barra.show_percentage = false
    _barra.max_value = 1.0
    var vazio := StyleBoxFlat.new()
    vazio.bg_color = Color(0.02, 0.03, 0.06, 0.95)
    vazio.set_corner_radius_all(7)
    _barra.add_theme_stylebox_override("background", vazio)
    var cheio := StyleBoxFlat.new()
    cheio.bg_color = Color(0.30, 0.58, 0.92)
    cheio.set_corner_radius_all(7)
    _barra.add_theme_stylebox_override("fill", cheio)
    ce.add_child(_barra)
    _xp = T.rotulo("", T.LEGENDA, T.TEXTO_FRACO)
    ce.add_child(_xp)
    ce.add_child(T.espaco(8))
    _poder = T.rotulo("", T.CORPO, T.OURO)
    ce.add_child(_poder)
    ce.add_child(T.espaco(6))
    _acao = T.botao("Subir nível", T.PRIMARIO)
    _acao.pressed.connect(_agir)
    ce.add_child(_acao)

    # ------------------------------------------------------- atributos
    var meio := T.coluna(18)
    meio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(meio)
    var cm := VBoxContainer.new()
    cm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cm.add_theme_constant_override("separation", 4)
    meio.add_child(cm)
    cm.add_child(T.rotulo("Atributos", T.TITULO_SECAO, T.OURO_FORTE))
    _pontos = T.rotulo("", T.CORPO, T.SUCESSO)
    cm.add_child(_pontos)
    cm.add_child(T.espaco(8))
    for id in NOMES:
        cm.add_child(_linha_de_atributo(String(id)))

    # --------------------------------------------------------- derivados
    var dir := T.coluna(18)
    dir.custom_minimum_size.x = 320
    linha.add_child(dir)
    var cd := VBoxContainer.new()
    cd.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cd.add_theme_constant_override("separation", 6)
    dir.add_child(cd)
    cd.add_child(T.rotulo("Em combate", T.TITULO_SECAO, T.OURO_FORTE))
    cd.add_child(T.espaco(8))
    _stats = VBoxContainer.new()
    _stats.add_theme_constant_override("separation", 8)
    cd.add_child(_stats)

func _linha_de_atributo(id: String) -> Control:
    var l := HBoxContainer.new()
    l.add_theme_constant_override("separation", 10)
    l.custom_minimum_size.y = 38
    var nome := T.rotulo(String(NOMES[id]), T.CORPO, T.TEXTO)
    nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_child(nome)
    var valor := T.rotulo("", T.CORPO, T.OURO_FORTE)
    valor.custom_minimum_size.x = 70
    valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    valor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_child(valor)
    var mais := T.botao("+", T.SECUNDARIO, 38.0)
    mais.custom_minimum_size.x = 48
    mais.pressed.connect(func():
        if _progresso: _progresso.investir_atributo(id))
    l.add_child(mais)
    _linhas[id] = {"valor": valor, "mais": mais}
    return l

func _agir() -> void:
    if _progresso == null: return
    if _progresso.esta_em_trava_de_ascensao(): _progresso.tentar_ascensao()
    else: _progresso.subir_nivel()

func _pintar() -> void:
    if _progresso == null or _nivel == null: return
    _nivel.text = "Nível %d" % _progresso.nivel
    var falta: float = float(_progresso.xp_para_nivel())
    _barra.value = clampf(float(_progresso.experiencia) / maxf(falta, 1.0), 0.0, 1.0)
    _xp.text = "%d / %d XP" % [_progresso.experiencia, int(falta)]
    _pontos.text = "%d ponto(s) a distribuir" % _progresso.pontos_de_atributo
    _pontos.add_theme_color_override("font_color",
        T.SUCESSO if _progresso.pontos_de_atributo > 0 else T.TEXTO_FRACO)
    _poder.text = "Poder de luta  %d" % int(_progresso.poder_de_luta_detalhado()["total"])
    for id in _linhas:
        _linhas[id]["valor"].text = str(_progresso.valor_atributo(String(id)))
        _linhas[id]["mais"].disabled = _progresso.pontos_de_atributo <= 0
    if _progresso.esta_em_trava_de_ascensao():
        _acao.text = "Ascensão"
        _acao.disabled = not _progresso.pode_pagar(_progresso.requisitos_da_ascensao())
    else:
        _acao.text = "Subir nível"
        _acao.disabled = not _progresso.pode_subir_nivel()
    for antigo in _stats.get_children(): antigo.queue_free()
    var e: Dictionary = _progresso.estatisticas()
    for par in [["Ataque", "%d" % int(e["ataque"])], ["Vida máxima", "%d" % int(e["vida_maxima"])],
            ["Defesa", "%d" % int(e["defesa"])], ["Crítico", "%.1f%%" % float(e["critico"])],
            ["Dano crítico", "%.0f%%" % float(e["dano_critico"])],
            ["Poder harmônico", "%d" % int(e["poder_harmonico"])]]:
        var l := HBoxContainer.new()
        var a := T.rotulo(String(par[0]), T.CORPO, T.TEXTO_FRACO)
        a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        l.add_child(a)
        l.add_child(T.rotulo(String(par[1]), T.CORPO, T.TEXTO))
        _stats.add_child(l)
