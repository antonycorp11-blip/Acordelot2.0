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
var _corrida_da_barra: Tween
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

    # O RETRATO OCUPA A COLUNA.
    #
    # Ele era um selo de 150 px no alto de uma coluna de 650 e o resto da tela
    # ficava vazio. Aqui ele cresce com o espaco que houver: numa ficha de
    # personagem, o personagem e que tem de ser a maior coisa da tela.
    var retrato := PanelContainer.new()
    retrato.custom_minimum_size = Vector2(0, 200)
    retrato.size_flags_vertical = Control.SIZE_EXPAND_FILL
    retrato.add_theme_stylebox_override("panel", T.estilo_do_kit(
        "moldura_painel_simples", Vector4i(40, 40, 40, 40), Vector4i(14, 14, 14, 14)))
    retrato.add_child(T.halo_redondo(Color(0.55, 0.68, 1.0), 0.20))
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

    ce.add_child(T.espaco(10))
    var nome := T.rotulo("Akles", T.TITULO_SECAO, T.OURO_FORTE)
    nome.add_theme_font_override("font", T.fonte_display())
    nome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ce.add_child(nome)
    _nivel = T.rotulo("", T.NOME_ITEM, T.TEXTO)
    _nivel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    ce.add_child(_nivel)
    ce.add_child(T.espaco(4))
    _barra = ProgressBar.new()
    _barra.custom_minimum_size.y = 18
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
    _acao = T.botao("Subir nível", T.PRIMARIO, 54.0)
    _acao.pressed.connect(_agir)
    ce.add_child(_acao)

    # ------------------------------------------------------- atributos
    var meio := T.coluna(18)
    # Margem larga a direita: com a coluna inteira o nome do atributo ficava a
    # meio metro do proprio numero.
    meio.add_theme_constant_override("margin_right", 90)
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
    # As linhas dividem a altura entre si em vez de se amontoarem no alto: a
    # coluna media 650 px e usava 300.
    for id in NOMES:
        var linha_do_atributo := _linha_de_atributo(String(id))
        linha_do_atributo.size_flags_vertical = Control.SIZE_EXPAND_FILL
        cm.add_child(linha_do_atributo)

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
    _stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cd.add_child(_stats)

func _linha_de_atributo(id: String) -> Control:
    var l := HBoxContainer.new()
    l.add_theme_constant_override("separation", 10)
    l.custom_minimum_size.y = 46
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
    # Sem isto o botao estica com a linha e vira uma coluna de 90 px de altura.
    mais.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
    # A BARRA ANDA, NAO PULA.
    #
    # Trocar o valor seco faz a experiencia ganha desaparecer sem ninguem ver.
    # Um quarto de segundo de percurso e o que transforma "o numero mudou" em
    # "eu progredi" — e e o unico lugar da ficha onde animar vale a pena.
    var destino: float = clampf(float(_progresso.experiencia) / maxf(falta, 1.0), 0.0, 1.0)
    if is_inside_tree() and absf(destino - _barra.value) > 0.001:
        if _corrida_da_barra and _corrida_da_barra.is_valid():
            _corrida_da_barra.kill()
        _corrida_da_barra = create_tween()
        _corrida_da_barra.tween_property(_barra, "value", destino, 0.28) \
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    else:
        _barra.value = destino
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
        l.size_flags_vertical = Control.SIZE_EXPAND_FILL
        var a := T.rotulo(String(par[0]), T.CORPO, T.TEXTO_FRACO)
        a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        l.add_child(a)
        l.add_child(T.rotulo(String(par[1]), T.CORPO, T.TEXTO))
        _stats.add_child(l)
