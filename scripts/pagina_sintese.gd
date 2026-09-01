extends Control
class_name PaginaSintese
## Purificar fragmento, condensar nota e forjar partitura — as tres operacoes
## que o Progresso ja sabe fazer, numa tela so.
const T := preload("res://scripts/ui_tema.gd")
const NOTAS := ["do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si"]
const ROTULO := {"do": "Dó", "do_sustenido": "Dó#", "re": "Ré", "re_sustenido": "Ré#",
    "mi": "Mi", "fa": "Fá", "fa_sustenido": "Fá#", "sol": "Sol",
    "sol_sustenido": "Sol#", "la": "Lá", "la_sustenido": "Lá#", "si": "Si"}
var _progresso: Node
var _grade: GridContainer
var _partituras: VBoxContainer

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

    var esq := T.coluna(16)
    esq.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    esq.size_flags_stretch_ratio = 2.0
    linha.add_child(esq)
    var ce := VBoxContainer.new()
    ce.add_theme_constant_override("separation", 8)
    esq.add_child(ce)
    ce.add_child(T.rotulo("Notas", T.TITULO_SECAO, T.OURO_FORTE))
    ce.add_child(T.rotulo("Purifique o fragmento corrompido e condense a nota.",
        T.CORPO, T.TEXTO_FRACO))
    ce.add_child(T.espaco(8))
    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
    ce.add_child(rol)
    _grade = GridContainer.new()
    _grade.columns = 2
    _grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grade.add_theme_constant_override("h_separation", 10)
    _grade.add_theme_constant_override("v_separation", 10)
    rol.add_child(_grade)

    var dir := T.coluna(16)
    dir.custom_minimum_size.x = 380
    linha.add_child(dir)
    var cd := VBoxContainer.new()
    cd.add_theme_constant_override("separation", 8)
    dir.add_child(cd)
    cd.add_child(T.rotulo("Partituras", T.TITULO_SECAO, T.OURO_FORTE))
    cd.add_child(T.rotulo("Trocam Claves por experiência.", T.CORPO, T.TEXTO_FRACO))
    cd.add_child(T.espaco(8))
    _partituras = VBoxContainer.new()
    _partituras.add_theme_constant_override("separation", 10)
    cd.add_child(_partituras)

func _pintar() -> void:
    if _progresso == null or _grade == null: return
    for a in _grade.get_children(): a.queue_free()
    for nota in NOTAS:
        _grade.add_child(_cartao_da_nota(String(nota)))
    for a in _partituras.get_children(): a.queue_free()
    for tipo in _progresso.PARTITURAS:
        _partituras.add_child(_cartao_da_partitura(String(tipo)))

func _cartao_da_nota(nota: String) -> Control:
    var p := T.coluna(12)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 5)
    p.add_child(col)
    var corrompido: int = _progresso.quantidade("fragmento_corrompido_" + nota)
    var limpo: int = _progresso.quantidade("fragmento_" + nota)
    var pronta: int = _progresso.quantidade("nota_" + nota)
    col.add_child(T.rotulo(String(ROTULO.get(nota, nota)), T.NOME_ITEM, T.OURO_FORTE))
    col.add_child(T.rotulo("corrompido %d   ·   puro %d   ·   nota %d"
        % [corrompido, limpo, pronta], T.LEGENDA, T.TEXTO_FRACO))
    var acoes := HBoxContainer.new()
    acoes.add_theme_constant_override("separation", 8)
    col.add_child(acoes)
    var purificar := T.botao("Purificar", T.SECUNDARIO, 38.0)
    purificar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    purificar.disabled = corrompido < 1 or _progresso.quantidade("claves") < _progresso.CUSTO_PURIFICAR_FRAGMENTO
    purificar.tooltip_text = "1 corrompido + %d Claves" % _progresso.CUSTO_PURIFICAR_FRAGMENTO
    purificar.pressed.connect(func(): _progresso.purificar_fragmento(nota))
    acoes.add_child(purificar)
    var condensar := T.botao("Condensar", T.PRIMARIO, 38.0)
    condensar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    condensar.disabled = limpo < 5 or _progresso.quantidade("claves") < _progresso.CUSTO_SINTETIZAR_NOTA
    condensar.tooltip_text = "5 puros + %d Claves" % _progresso.CUSTO_SINTETIZAR_NOTA
    condensar.pressed.connect(func(): _progresso.sintetizar_nota(nota))
    acoes.add_child(condensar)
    return p

func _cartao_da_partitura(tipo: String) -> Control:
    var receita: Dictionary = _progresso.PARTITURAS[tipo]
    var p := T.coluna(12)
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation", 5)
    p.add_child(col)
    col.add_child(T.rotulo(String(receita["nome"]), T.NOME_ITEM, T.OURO_FORTE))
    col.add_child(T.rotulo("%d Claves  →  %d XP   ·   tem %d"
        % [int(receita["custo"]), int(receita["xp"]),
           _progresso.quantidade(String(receita["recurso"]))], T.LEGENDA, T.TEXTO_FRACO))
    var acoes := HBoxContainer.new()
    acoes.add_theme_constant_override("separation", 8)
    col.add_child(acoes)
    var forjar := T.botao("Forjar", T.SECUNDARIO, 38.0)
    forjar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    forjar.disabled = _progresso.quantidade("claves") < int(receita["custo"])
    forjar.pressed.connect(func(): _progresso.criar_partitura(tipo))
    acoes.add_child(forjar)
    var usar := T.botao("Usar", T.PRIMARIO, 38.0)
    usar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    usar.disabled = _progresso.quantidade(String(receita["recurso"])) <= 0
    usar.pressed.connect(func(): _progresso.usar_partitura(tipo))
    acoes.add_child(usar)
    return p
