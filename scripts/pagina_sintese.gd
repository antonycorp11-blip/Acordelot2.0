extends Control
class_name PaginaSintese
## A OFICINA, no formato do protótipo: lista a esquerda, palco no meio, o que
## sai a direita.
##
## O protótipo tinha receita, palco e resultado previsto. A oficina deste jogo
## nao trabalha com receita de tres ingredientes — ela leva UMA nota por tres
## estados: fragmento corrompido, fragmento puro, nota pronta. Entao a mesma
## forma foi mantida e o conteudo e o de verdade: a lista mostra as doze notas
## com o quanto cada uma avancou, o palco mostra a nota escolhida com os tres
## estados, e a direita diz o que a acao custa e o que devolve. Nenhum numero
## aqui e enfeite: todos saem do Progresso.
const T := preload("res://scripts/ui_tema.gd")

const NOTAS := ["do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si"]
const ROTULO := {"do": "Dó", "do_sustenido": "Dó#", "re": "Ré", "re_sustenido": "Ré#",
    "mi": "Mi", "fa": "Fá", "fa_sustenido": "Fá#", "sol": "Sol",
    "sol_sustenido": "Sol#", "la": "Lá", "la_sustenido": "Lá#", "si": "Si"}
## Sete pedras para doze notas: a sustenida usa a pedra da natural, e o nome ao
## lado faz a diferenca que a cor nao faria.
const CRISTAL_DA_NOTA := {
    "do": "do", "do_sustenido": "do", "re": "re", "re_sustenido": "re",
    "mi": "mi", "fa": "fa", "fa_sustenido": "fa", "sol": "sol",
    "sol_sustenido": "sol", "la": "la", "la_sustenido": "la", "si": "si",
}
## Quantos fragmentos puros uma nota pede. Vem do Progresso; aqui so para o texto.
const PUROS_POR_NOTA := 5

var _progresso: Node
var _escolhida := "do"
var _lista: VBoxContainer
var _linhas: Dictionary = {}
var _palco_nome: Label
var _palco_pedra: TextureRect
var _palco_halo: TextureRect
var _estados: HBoxContainer
var _purificar: Button
var _condensar: Button
var _resultado: VBoxContainer
var _partituras: VBoxContainer
var _pulso: Tween


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
    linha.add_theme_constant_override("separation", 10)
    add_child(linha)

    # ------------------------------------------------------- as doze notas
    var esq := T.painel_do_proto(14)
    esq.custom_minimum_size.x = 266
    linha.add_child(esq)
    var ce := VBoxContainer.new()
    ce.add_theme_constant_override("separation", 4)
    esq.add_child(ce)
    ce.add_child(T.cabeca_de_painel("Oficina do Maestro", "Notas"))
    ce.add_child(T.espaco(6))
    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
    ce.add_child(rol)
    _lista = VBoxContainer.new()
    _lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _lista.add_theme_constant_override("separation", 5)
    rol.add_child(_lista)
    for nota in NOTAS:
        var l := _linha_da_nota(String(nota))
        _lista.add_child(l)

    # -------------------------------------------------------------- palco
    var meio := T.painel_do_proto(16)
    meio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(meio)
    var cm := VBoxContainer.new()
    cm.add_theme_constant_override("separation", 6)
    meio.add_child(cm)

    var topo := VBoxContainer.new()
    topo.add_theme_constant_override("separation", 0)
    cm.add_child(topo)
    topo.add_child(T.sobrancelha("Nota em trabalho"))
    _palco_nome = T.titulo_do_proto("", 34)
    topo.add_child(_palco_nome)

    var vitrine := Control.new()
    vitrine.size_flags_vertical = Control.SIZE_EXPAND_FILL
    vitrine.custom_minimum_size.y = 140
    vitrine.mouse_filter = Control.MOUSE_FILTER_IGNORE
    cm.add_child(vitrine)
    _palco_halo = T.halo_redondo(Color(1, 1, 1), 0.30)
    vitrine.add_child(_palco_halo)
    _palco_pedra = TextureRect.new()
    _palco_pedra.set_anchors_preset(Control.PRESET_FULL_RECT)
    _palco_pedra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _palco_pedra.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _palco_pedra.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vitrine.add_child(_palco_pedra)

    # OS TRES ESTADOS, lado a lado: e o caminho que o fragmento percorre ate
    # virar nota, e ver os tres juntos e o que explica a oficina sem texto.
    _estados = HBoxContainer.new()
    _estados.add_theme_constant_override("separation", 12)
    _estados.alignment = BoxContainer.ALIGNMENT_CENTER
    cm.add_child(_estados)
    cm.add_child(T.espaco(6))

    var acoes := HBoxContainer.new()
    acoes.add_theme_constant_override("separation", 10)
    cm.add_child(acoes)
    _purificar = T.botao("Purificar", T.SECUNDARIO, 52.0)
    _purificar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _purificar.pressed.connect(_ao_purificar)
    acoes.add_child(_purificar)
    _condensar = T.botao("Condensar", T.PRIMARIO, 52.0)
    _condensar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _condensar.pressed.connect(_ao_condensar)
    acoes.add_child(_condensar)

    # ----------------------------------------------------- o que sai disso
    var dir := T.painel_do_proto(14)
    dir.custom_minimum_size.x = 274
    linha.add_child(dir)
    var cd := VBoxContainer.new()
    cd.add_theme_constant_override("separation", 4)
    dir.add_child(cd)
    cd.add_child(T.cabeca_de_painel("Resultado previsto", "Custos"))
    cd.add_child(T.espaco(6))
    _resultado = VBoxContainer.new()
    _resultado.add_theme_constant_override("separation", 0)
    cd.add_child(_resultado)
    cd.add_child(T.espaco(10))
    cd.add_child(T.sobrancelha("Estudo"))
    cd.add_child(T.titulo_do_proto("Partituras", 24))
    # AS PARTITURAS ROLAM DENTRO DA PROPRIA COLUNA.
    #
    # Com os custos em cima e tres partituras embaixo, a coluna pedia 717 px de
    # altura numa area de 630 e empurrava a pagina para fora da moldura. A
    # rolagem aqui e o unico lugar onde ela cabe: a lista de partituras cresce
    # com o jogo, e o resto da tela nao pode encolher por causa dela.
    var rol_p := ScrollContainer.new()
    rol_p.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol_p.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cd.add_child(rol_p)
    _partituras = VBoxContainer.new()
    _partituras.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _partituras.add_theme_constant_override("separation", 8)
    rol_p.add_child(_partituras)


## Uma linha da lista: pedra, nome, quanto avancou. A barra mostra o caminho
## ate a proxima nota — cinco puros — porque e isso que o jogador persegue.
func _linha_da_nota(nota: String) -> Control:
    var b := Button.new()
    b.focus_mode = Control.FOCUS_NONE
    b.custom_minimum_size.y = 52
    for estado in ["normal", "hover", "pressed", "focus"]:
        b.add_theme_stylebox_override(estado, StyleBoxEmpty.new())
    b.pressed.connect(func(): _escolher(nota))

    var moldura := Panel.new()
    moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
    moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(moldura)

    var caixa := HBoxContainer.new()
    caixa.set_anchors_preset(Control.PRESET_FULL_RECT)
    caixa.offset_left = 8.0
    caixa.offset_right = -8.0
    caixa.add_theme_constant_override("separation", 8)
    caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    b.add_child(caixa)

    var pedra := TextureRect.new()
    pedra.texture = _cristal(nota)
    pedra.custom_minimum_size = Vector2(34, 34)
    pedra.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    pedra.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    pedra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    pedra.mouse_filter = Control.MOUSE_FILTER_IGNORE
    caixa.add_child(pedra)

    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    col.add_theme_constant_override("separation", 2)
    caixa.add_child(col)
    var nome := T.rotulo_simples(String(ROTULO.get(nota, nota)), 19, T.CREME)
    col.add_child(nome)
    var barra := T.barra(Color(0.42, 0.72, 1.0), Color(0.55, 0.82, 1.0), 5.0)
    col.add_child(barra)

    var conta := T.rotulo_simples("", 15, T.SOBRANCELHA)
    conta.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    caixa.add_child(conta)

    _linhas[nota] = {"moldura": moldura, "nome": nome, "barra": barra,
        "conta": conta, "pedra": pedra}
    return b


func _bolha(rotulo: String, quanto: int, cor: Color) -> Control:
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 2)
    var disco := PanelContainer.new()
    disco.custom_minimum_size = Vector2(66, 66)
    var e := StyleBoxFlat.new()
    e.bg_color = Color(cor.r * 0.16, cor.g * 0.16, cor.b * 0.20, 0.85)
    e.border_color = Color(cor.r, cor.g, cor.b, 0.75 if quanto > 0 else 0.28)
    e.set_border_width_all(1)
    e.set_corner_radius_all(37)
    disco.add_theme_stylebox_override("panel", e)
    var n := T.rotulo_simples(str(quanto), 26, T.CREME if quanto > 0 else T.SOBRANCELHA)
    n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    disco.add_child(n)
    col.add_child(disco)
    var r := T.sobrancelha(rotulo)
    r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    col.add_child(r)
    return col


func _cristal(nota: String) -> Texture2D:
    var caminho := "res://textures/ui/kit/item/cristal_%s.png" % String(
        CRISTAL_DA_NOTA.get(nota, "do"))
    return load(caminho) if ResourceLoader.exists(caminho) else null


func _escolher(nota: String) -> void:
    _escolhida = nota
    _pintar()
    # Um pulso curto na pedra confirma a troca sem barulho.
    if _pulso and _pulso.is_valid():
        _pulso.kill()
    _palco_pedra.scale = Vector2(0.94, 0.94)
    _palco_pedra.pivot_offset = _palco_pedra.size * 0.5
    _pulso = create_tween()
    _pulso.tween_property(_palco_pedra, "scale", Vector2.ONE, 0.22) \
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _ao_purificar() -> void:
    if _progresso == null: return
    _progresso.purificar_fragmento(_escolhida)
    _avisar("Fragmento purificado",
        "%s pronto para condensar" % String(ROTULO.get(_escolhida, _escolhida)))


func _ao_condensar() -> void:
    if _progresso == null: return
    _progresso.sintetizar_nota(_escolhida)
    _avisar("Harmonia fortalecida",
        "Nota de %s condensada" % String(ROTULO.get(_escolhida, _escolhida)))


func _avisar(sobre: String, texto: String) -> void:
    var casca := get_tree().root.find_child("UiShell", true, false)
    if casca and casca.has_method("avisar"):
        casca.avisar(sobre, texto)


func _pintar() -> void:
    if _progresso == null or _lista == null:
        return
    var claves: int = _progresso.quantidade("claves")

    for nota in NOTAS:
        var id := String(nota)
        var corrompido: int = _progresso.quantidade("fragmento_corrompido_" + id)
        var limpo: int = _progresso.quantidade("fragmento_" + id)
        var pronta: int = _progresso.quantidade("nota_" + id)
        var d: Dictionary = _linhas[id]
        d["conta"].text = "%d" % (corrompido + limpo + pronta)
        d["barra"].value = clampf(float(limpo) / float(PUROS_POR_NOTA), 0.0, 1.0)
        var ativa: bool = id == _escolhida
        d["nome"].add_theme_color_override("font_color", T.OURO_FORTE if ativa else T.CREME)
        d["pedra"].modulate = Color(1, 1, 1, 1.0 if (ativa or corrompido + limpo + pronta > 0) else 0.4)
        var e := StyleBoxFlat.new()
        e.bg_color = Color(0.078, 0.110, 0.180, 0.95) if ativa else Color(0, 0, 0, 0)
        e.border_color = T.OURO_ARO if ativa else Color(0, 0, 0, 0)
        e.set_border_width_all(1 if ativa else 0)
        e.set_corner_radius_all(3)
        d["moldura"].add_theme_stylebox_override("panel", e)

    var corrompido_atual: int = _progresso.quantidade("fragmento_corrompido_" + _escolhida)
    var limpo_atual: int = _progresso.quantidade("fragmento_" + _escolhida)
    var pronta_atual: int = _progresso.quantidade("nota_" + _escolhida)

    _palco_nome.text = "Nota de %s" % String(ROTULO.get(_escolhida, _escolhida))
    _palco_pedra.texture = _cristal(_escolhida)
    var tem_algo: bool = corrompido_atual + limpo_atual + pronta_atual > 0
    _palco_pedra.modulate = Color(1, 1, 1, 1.0 if tem_algo else 0.35)
    _palco_halo.modulate = Color(0.55, 0.78, 1.0, 1.0 if tem_algo else 0.0)

    for antigo in _estados.get_children():
        _estados.remove_child(antigo)
        antigo.queue_free()
    _estados.add_child(_bolha("Corrompido", corrompido_atual, Color(0.85, 0.42, 0.35)))
    _estados.add_child(_bolha("Puro", limpo_atual, Color(0.42, 0.75, 1.0)))
    _estados.add_child(_bolha("Nota", pronta_atual, Color(0.95, 0.78, 0.38)))

    _purificar.disabled = corrompido_atual < 1 or claves < _progresso.CUSTO_PURIFICAR_FRAGMENTO
    _purificar.tooltip_text = "1 corrompido + %d Claves" % _progresso.CUSTO_PURIFICAR_FRAGMENTO
    _condensar.disabled = limpo_atual < PUROS_POR_NOTA or claves < _progresso.CUSTO_SINTETIZAR_NOTA
    _condensar.tooltip_text = "%d puros + %d Claves" % [PUROS_POR_NOTA, _progresso.CUSTO_SINTETIZAR_NOTA]

    for antigo in _resultado.get_children():
        _resultado.remove_child(antigo)
        antigo.queue_free()
    _resultado.add_child(T.linha_de_status("Purificar custa",
        "%d Claves" % _progresso.CUSTO_PURIFICAR_FRAGMENTO))
    _resultado.add_child(T.linha_de_status("Condensar custa",
        "%d Claves" % _progresso.CUSTO_SINTETIZAR_NOTA))
    _resultado.add_child(T.linha_de_status("Puros por nota", str(PUROS_POR_NOTA)))
    _resultado.add_child(T.linha_de_status("Claves em mãos", str(claves)))

    for antigo in _partituras.get_children():
        _partituras.remove_child(antigo)
        antigo.queue_free()
    for tipo in _progresso.PARTITURAS:
        _partituras.add_child(_cartao_da_partitura(String(tipo)))


func _cartao_da_partitura(tipo: String) -> Control:
    var receita: Dictionary = _progresso.PARTITURAS[tipo]
    var pode: bool = _progresso.quantidade("claves") >= int(receita["custo"])
    var tem: int = _progresso.quantidade(String(receita["recurso"]))
    var p := PanelContainer.new()
    var e := StyleBoxFlat.new()
    e.bg_color = Color(0.055, 0.085, 0.145, 0.55) if pode else Color(0.03, 0.045, 0.08, 0.40)
    e.border_color = T.OURO_ARO if pode else Color(0.14, 0.18, 0.26, 0.7)
    e.set_border_width_all(1)
    e.set_corner_radius_all(3)
    for lado in ["content_margin_left", "content_margin_right"]:
        e.set(lado, 10)
    e.content_margin_top = 8
    e.content_margin_bottom = 8
    p.add_theme_stylebox_override("panel", e)

    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 3)
    p.add_child(col)
    col.add_child(T.rotulo_simples(String(receita["nome"]), 18, T.OURO_FORTE))
    col.add_child(T.rotulo_simples("%d Claves  →  %d XP   ·   tem %d"
        % [int(receita["custo"]), int(receita["xp"]), tem], 14, T.SOBRANCELHA))
    var acoes := HBoxContainer.new()
    acoes.add_theme_constant_override("separation", 6)
    col.add_child(acoes)
    var forjar := T.botao("Forjar", T.SECUNDARIO, 34.0)
    forjar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    forjar.disabled = not pode
    forjar.pressed.connect(func():
        _progresso.criar_partitura(tipo)
        _avisar("Partitura forjada", String(receita["nome"])))
    acoes.add_child(forjar)
    var usar := T.botao("Usar", T.PRIMARIO, 34.0)
    usar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    usar.disabled = tem <= 0
    usar.pressed.connect(func():
        _progresso.usar_partitura(tipo)
        _avisar("Experiência absorvida", "+%d XP" % int(receita["xp"])))
    acoes.add_child(usar)
    return p
