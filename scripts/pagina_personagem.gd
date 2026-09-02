extends Control
class_name PaginaPersonagem
## Ficha dos herois jogaveis. Akles e Wins ficam sempre acessiveis no topo;
## trocar aqui troca tambem o personagem ativo no mundo, e o palco usa o mesmo
## modelo original usado durante a partida.
##
## O desenho e o do prototipo. O conteudo e o do jogo: a coluna da esquerda tem
## os atributos que voce realmente distribui, e nao slots de equipamento — o
## jogo nao tem equipamento, e desenhar quatro caixas vazias com "espaco
## bloqueado" seria prometer sistema que nao existe. A trilha de baixo tambem
## deixou de ser enfeite: ela mostra as duas ascensoes de verdade, nivel 20 e 40.
const P := preload("res://scripts/ui_proto.gd")
const PalcoScript := preload("res://scripts/palco_akles.gd")

const NOMES := {"forca": "Força", "destreza": "Destreza", "vitalidade": "Vitalidade",
    "ressonancia": "Ressonância", "percepcao": "Percepção"}

var _progresso: Node
var _palco: PalcoAkles
var _palco_caixa: Control
var _papel_no_palco: Label
var _nome_no_palco: Label
var _selecionado := "akles"
var _botoes_heroi: Dictionary = {}
var _pontos: Label
var _linhas: Dictionary = {}
var _nivel: Label
var _xp: Label
var _barra: ProgressBar
var _corrida: Tween
var _poder: Label
var _stats: VBoxContainer
var _acao: Button
var _trilha: HBoxContainer
var _resumo_trilha: Label


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)


func ao_abrir() -> void:
    _sincronizar_com_jogo()
    if _palco:
        _palco.ligar()
    _pintar()


func ao_fechar() -> void:
    if _palco:
        _palco.desligar()


func _montar() -> void:
    var pagina := VBoxContainer.new()
    pagina.set_anchors_preset(Control.PRESET_FULL_RECT)
    pagina.add_theme_constant_override("separation", 12)
    add_child(pagina)

    var seletor := HBoxContainer.new()
    seletor.alignment = BoxContainer.ALIGNMENT_CENTER
    seletor.add_theme_constant_override("separation", 8)
    pagina.add_child(seletor)
    for dados in [["akles", "Akles", "Maestro da Vigília"], ["wins", "Wins", "Guardiã da Aurora"]]:
        var b := P.botao("%s\n%s" % [String(dados[1]), String(dados[2])], "quiet")
        b.custom_minimum_size = Vector2(210, 52)
        b.pressed.connect(_escolher_heroi.bind(String(dados[0])))
        seletor.add_child(b)
        _botoes_heroi[String(dados[0])] = b
    var futuro := P.botao("＋ Próximos heróis", "quiet")
    futuro.custom_minimum_size = Vector2(180, 52)
    futuro.disabled = true
    seletor.add_child(futuro)

    var alto := HBoxContainer.new()
    alto.size_flags_vertical = Control.SIZE_EXPAND_FILL
    alto.add_theme_constant_override("separation", 12)
    pagina.add_child(alto)

    # ---------------------------------------------------------- atributos
    var esq := P.painel()
    esq.custom_minimum_size.x = 290
    alto.add_child(esq)
    var ce := VBoxContainer.new()
    ce.add_theme_constant_override("separation", 4)
    esq.add_child(P.recheio(ce, 15))
    ce.add_child(P.cabecalho("TALENTO BRUTO", "Atributos", ""))
    _pontos = P.rotulo("", 11, P.GREEN)
    ce.add_child(_pontos)
    ce.add_child(P.risco())
    for id in NOMES:
        ce.add_child(_linha_de_atributo(String(id)))
    ce.add_child(P.espaco_elastico())

    # -------------------------------------------------------------- palco
    var meio := P.painel(Color("08162ce8"))
    meio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    alto.add_child(meio)
    _palco_caixa = Control.new()
    _palco_caixa.clip_contents = true
    meio.add_child(_palco_caixa)

    var ident := VBoxContainer.new()
    ident.position = Vector2(16, 12)
    ident.add_theme_constant_override("separation", 0)
    ident.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _palco_caixa.add_child(ident)
    _papel_no_palco = P.sobrancelha("MAESTRO DA VIGÍLIA")
    ident.add_child(_papel_no_palco)
    _nome_no_palco = P.rotulo("Akles", 29, P.IVORY)
    ident.add_child(_nome_no_palco)

    _recriar_palco()

    # ------------------------------------------------------------ evolucao
    var dir := P.painel()
    dir.custom_minimum_size.x = 310
    alto.add_child(dir)
    var cd := VBoxContainer.new()
    cd.add_theme_constant_override("separation", 6)
    dir.add_child(P.recheio(cd, 15))
    var topo := HBoxContainer.new()
    topo.add_theme_constant_override("separation", 8)
    cd.add_child(topo)
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", 0)
    topo.add_child(col)
    col.add_child(P.sobrancelha("EVOLUÇÃO ATUAL"))
    _nivel = P.rotulo("", 26, P.IVORY)
    col.add_child(_nivel)
    _xp = P.rotulo("", 10, P.MUTED)
    _xp.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    topo.add_child(_xp)

    _barra = ProgressBar.new()
    _barra.max_value = 1.0
    _barra.show_percentage = false
    _barra.custom_minimum_size.y = 8
    _barra.add_theme_stylebox_override("background", P.estilo(Color("07101f"), Color("58472f"), 1, 1))
    _barra.add_theme_stylebox_override("fill", P.estilo(P.GOLD, P.GOLD_BRIGHT, 0, 1))
    cd.add_child(_barra)

    var poder_linha := HBoxContainer.new()
    poder_linha.add_theme_constant_override("separation", 10)
    cd.add_child(poder_linha)
    poder_linha.add_child(P.rotulo("⚡", 22, P.GOLD_BRIGHT))
    _poder = P.rotulo("", 27, P.GOLD_BRIGHT)
    poder_linha.add_child(_poder)
    poder_linha.add_child(P.rotulo("PODER TOTAL", 15, P.IVORY))
    cd.add_child(P.risco())

    _stats = VBoxContainer.new()
    _stats.add_theme_constant_override("separation", 0)
    _stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cd.add_child(_stats)
    _acao = P.botao("Subir nível", "gold")
    _acao.custom_minimum_size.y = 48
    _acao.pressed.connect(_agir)
    cd.add_child(_acao)

    # -------------------------------------------------------------- trilha
    var faixa := P.painel(Color("081221ed"))
    faixa.custom_minimum_size.y = 150
    pagina.add_child(faixa)
    var cf := HBoxContainer.new()
    cf.add_theme_constant_override("separation", 18)
    faixa.add_child(P.recheio(cf, 14))
    var titulo := VBoxContainer.new()
    titulo.custom_minimum_size.x = 210
    titulo.add_theme_constant_override("separation", 0)
    cf.add_child(titulo)
    titulo.add_child(P.sobrancelha("TRILHA DE MAESTRIA"))
    titulo.add_child(P.rotulo("Ascensão", 24, P.IVORY))
    _resumo_trilha = P.rotulo("", 10, P.MUTED)
    titulo.add_child(_resumo_trilha)
    _trilha = HBoxContainer.new()
    _trilha.add_theme_constant_override("separation", 12)
    _trilha.alignment = BoxContainer.ALIGNMENT_CENTER
    _trilha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cf.add_child(_trilha)


func _linha_de_atributo(id: String) -> Control:
    var l := HBoxContainer.new()
    l.custom_minimum_size.y = 42
    l.add_theme_constant_override("separation", 8)
    var nome := P.rotulo(String(NOMES[id]), 12, Color("c3b89f"))
    nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    l.add_child(nome)
    var valor := P.rotulo("", 15, P.IVORY)
    valor.custom_minimum_size.x = 42
    valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    l.add_child(valor)
    var mais := P.botao("+")
    mais.custom_minimum_size = Vector2(40, 32)
    mais.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    mais.pressed.connect(func():
        if _progresso: _progresso.investir_atributo(id))
    l.add_child(mais)
    _linhas[id] = {"valor": valor, "mais": mais}
    return l


## Cada degrau da trilha e um marco REAL: os niveis em que a ascensao trava e
## pede item de chefe. Cinco bolinhas decorativas nao diriam nada.
func _degrau(rotulo: String, sub: String, conquistado: bool, agora: bool) -> Control:
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 2)
    var disco := PanelContainer.new()
    disco.custom_minimum_size = Vector2(74, 74)
    var cor: Color = P.GOLD_BRIGHT if conquistado else (P.CYAN if agora else Color("37415a"))
    disco.add_theme_stylebox_override("panel",
        P.estilo(Color(cor.r * 0.14, cor.g * 0.14, cor.b * 0.18, 0.9), cor, 1, 37))
    var n := P.rotulo(rotulo, 17, P.IVORY if (conquistado or agora) else P.MUTED)
    n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    disco.add_child(n)
    col.add_child(disco)
    var s := P.rotulo(sub, 9, P.GOLD_BRIGHT if conquistado else P.MUTED)
    s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(s)
    return col


func _agir() -> void:
    if _progresso == null: return
    var antes: int = _progresso.nivel
    if _progresso.esta_em_trava_de_ascensao(): _progresso.tentar_ascensao()
    else: _progresso.subir_nivel()
    if _progresso.nivel > antes:
        var casca := get_tree().root.find_child("UiShell", true, false)
        if casca and casca.has_method("avisar"):
            casca.avisar("Harmonia fortalecida", "%s alcançou o nível %d" % [_nome_heroi(), _progresso.nivel])


func _sincronizar_com_jogo() -> void:
    var jogador := get_tree().get_first_node_in_group("jogador")
    if jogador and jogador.has_method("personagem_atual"):
        var atual := String(jogador.personagem_atual())
        if atual in ["akles", "wins"] and atual != _selecionado:
            _selecionado = atual
            _recriar_palco()


func _escolher_heroi(id: String) -> void:
    if id == _selecionado:
        return
    var jogador := get_tree().get_first_node_in_group("jogador")
    if jogador and jogador.has_method("trocar_personagem"):
        jogador.trocar_personagem(id)
    _selecionado = id
    _recriar_palco()
    _pintar()
    var casca := get_tree().root.find_child("UiShell", true, false)
    if casca and casca.has_method("avisar"):
        casca.avisar("Herói selecionado", _nome_heroi() + " agora está em campo")


func _recriar_palco() -> void:
    if _palco_caixa == null:
        return
    if _palco:
        _palco_caixa.remove_child(_palco)
        _palco.queue_free()
    _palco = PalcoScript.new(false, _selecionado)
    _palco.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # O modelo vem antes da identificação para o texto permanecer por cima.
    _palco_caixa.add_child(_palco)
    _palco_caixa.move_child(_palco, 0)
    if visible:
        _palco.ligar()


func _nome_heroi() -> String:
    return "Wins" if _selecionado == "wins" else "Akles"


func _pintar() -> void:
    if _progresso == null: return
    for id in _botoes_heroi:
        var botao: Button = _botoes_heroi[id]
        botao.add_theme_stylebox_override("normal", P.estilo_de_botao(
            "gold" if String(id) == _selecionado else "quiet"))
    var falta := float(_progresso.xp_para_nivel())
    _nivel.text = "Nível %d" % _progresso.nivel
    _papel_no_palco.text = "GUARDIÃ DA AURORA" if _selecionado == "wins" else "MAESTRO DA VIGÍLIA"
    _nome_no_palco.text = "%s   NÍVEL %d" % [_nome_heroi(), _progresso.nivel]
    _xp.text = "%d / %d XP" % [_progresso.experiencia, int(falta)]
    var destino: float = clampf(float(_progresso.experiencia) / maxf(falta, 1.0), 0.0, 1.0)
    if is_inside_tree() and absf(destino - _barra.value) > 0.001:
        if _corrida and _corrida.is_valid(): _corrida.kill()
        _corrida = create_tween()
        _corrida.tween_property(_barra, "value", destino, 0.28) \
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    else:
        _barra.value = destino

    _pontos.text = "%d ponto(s) a distribuir" % _progresso.pontos_de_atributo
    _pontos.add_theme_color_override("font_color",
        P.GREEN if _progresso.pontos_de_atributo > 0 else P.MUTED)
    _poder.text = _milhar(int(_progresso.poder_de_luta_detalhado()["total"]))
    for id in _linhas:
        _linhas[id]["valor"].text = str(_progresso.valor_atributo(String(id)))
        _linhas[id]["mais"].disabled = _progresso.pontos_de_atributo <= 0

    if _progresso.esta_em_trava_de_ascensao():
        _acao.text = "Ascensão"
        _acao.disabled = not _progresso.pode_pagar(_progresso.requisitos_da_ascensao())
    else:
        _acao.text = "Subir nível"
        _acao.disabled = not _progresso.pode_subir_nivel()

    for antigo in _stats.get_children():
        _stats.remove_child(antigo)
        antigo.queue_free()
    var e: Dictionary = _progresso.estatisticas()
    for par in [["♡", "Vida", "%d" % int(e["vida_maxima"])],
            ["♪", "Ressonância", "%d" % int(e["poder_harmonico"])],
            ["⚔", "Ataque", "%d" % int(e["ataque"])],
            ["◈", "Defesa", "%d" % int(e["defesa"])],
            ["✣", "Taxa crítica", "%.1f%%" % float(e["critico"])]]:
        _stats.add_child(P.linha_de_status(String(par[0]), String(par[1]), String(par[2])))

    for antigo in _trilha.get_children():
        _trilha.remove_child(antigo)
        antigo.queue_free()
    var nivel: int = _progresso.nivel
    var marcos := [[10, "10"], [20, "20"], [30, "30"], [40, "40"], [int(_progresso.NIVEL_MAXIMO), "MAX"]]
    var vencidos := 0
    for m in marcos:
        var alvo: int = int(m[0])
        var conquistado: bool = nivel >= alvo
        if conquistado: vencidos += 1
        _trilha.add_child(_degrau(String(m[1]),
            "Conquistado" if conquistado else ("Próximo" if nivel >= alvo - 10 else "Bloqueado"),
            conquistado, not conquistado and nivel >= alvo - 10))
    _resumo_trilha.text = "%d de %d marcos" % [vencidos, marcos.size()]


func _milhar(valor: int) -> String:
    var texto := str(valor)
    var saida := ""
    var conta := 0
    for i in range(texto.length() - 1, -1, -1):
        saida = texto[i] + saida
        conta += 1
        if conta % 3 == 0 and i > 0:
            saida = "." + saida
    return saida
