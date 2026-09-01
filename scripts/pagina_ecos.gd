extends Control
class_name PaginaEcos
## Os doze Ecos: quais foram descobertos e qual esta equipado.
const T := preload("res://scripts/ui_tema.gd")
const NOTAS := ["do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si"]
const ROTULO := {"do": "Dó", "do_sustenido": "Dó#", "re": "Ré", "re_sustenido": "Ré#",
    "mi": "Mi", "fa": "Fá", "fa_sustenido": "Fá#", "sol": "Sol",
    "sol_sustenido": "Sol#", "la": "Lá", "la_sustenido": "Lá#", "si": "Si"}
var _progresso: Node
var _colecao: Label
var _grade: GridContainer

func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)

func ao_abrir() -> void: _pintar()

func _montar() -> void:
    var col := VBoxContainer.new()
    col.set_anchors_preset(Control.PRESET_FULL_RECT)
    col.add_theme_constant_override("separation", 8)
    add_child(col)
    _colecao = T.rotulo("", T.TITULO_SECAO, T.OURO_FORTE)
    col.add_child(_colecao)
    col.add_child(T.espaco(8))
    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(rol)
    _grade = GridContainer.new()
    _grade.columns = 4
    _grade.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _grade.add_theme_constant_override("h_separation", 12)
    _grade.add_theme_constant_override("v_separation", 12)
    rol.add_child(_grade)

func _pintar() -> void:
    if _progresso == null or _grade == null: return
    for a in _grade.get_children(): a.queue_free()
    var achados: Array = _progresso.ecos_descobertos
    _colecao.text = "Coleção  %d / 12" % achados.size()
    var equipado := String(_progresso.eco_equipado.get("id", ""))
    for nota in NOTAS:
        var id := String(nota)
        var tem: bool = id in achados
        var p := PanelContainer.new()
        p.custom_minimum_size.y = 128
        p.add_theme_stylebox_override("panel", T.painel(
            T.NAVY_CLARO if tem else Color(0.03, 0.04, 0.07, 0.9),
            T.OURO if id == equipado else (T.RARIDADE["Raro"] if tem else Color(0.20, 0.24, 0.32)),
            10, 2 if id == equipado else 1, 12))
        var c := VBoxContainer.new()
        c.add_theme_constant_override("separation", 4)
        p.add_child(c)
        var n := T.rotulo("Eco de " + String(ROTULO.get(id, id)), T.NOME_ITEM,
            T.OURO_FORTE if tem else T.TEXTO_FRACO)
        n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        c.add_child(n)
        var alma: int = _progresso.quantidade("alma_eco_" + id)
        var s := T.rotulo(("Alma  %d" % alma) if tem else "Não ressoado", T.LEGENDA, T.TEXTO_FRACO)
        s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        c.add_child(s)
        c.add_child(T.espaco(2))
        var b := T.botao("Equipado" if id == equipado else "Equipar",
            T.PRIMARIO if id == equipado else T.SECUNDARIO, 38.0)
        b.disabled = not tem or id == equipado
        b.pressed.connect(func():
            _progresso.equipar_eco({"id": id, "nome": "Eco de " + String(ROTULO.get(id, id)),
                "poder": 60 + achados.size() * 8}))
        c.add_child(b)
        _grade.add_child(p)
