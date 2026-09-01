extends Control
class_name PaginaTalentos
## Os quatro talentos, o nivel de cada um e onde gastar o ponto.
const T := preload("res://scripts/ui_tema.gd")
const TALENTOS := [
    ["ataque_basico", "Golpe Ressonante", "Ataque corpo a corpo que marca o compasso."],
    ["skill_1", "Aura Azul", "Envolve o Akles numa aura que absorve dano."],
    ["skill_2", "Espada Gigante", "Amplia a lâmina e alcança vários Shikers."],
    ["skill_3", "Raio Harmônico", "Feixe direcionado que atravessa a linha inimiga."],
]
var _progresso: Node
var _pontos: Label
var _linhas: Dictionary = {}

func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)

func ao_abrir() -> void: _pintar()

func _montar() -> void:
    var col := VBoxContainer.new()
    col.set_anchors_preset(Control.PRESET_FULL_RECT)
    col.add_theme_constant_override("separation", 10)
    add_child(col)
    _pontos = T.rotulo_simples("", 19, T.GANHO)
    col.add_child(_pontos)
    col.add_child(T.espaco(8))
    var rol := ScrollContainer.new()
    rol.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    rol.size_flags_vertical = Control.SIZE_EXPAND_FILL
    col.add_child(rol)
    var lista := VBoxContainer.new()
    lista.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    lista.add_theme_constant_override("separation", 10)
    rol.add_child(lista)
    for t in TALENTOS:
        lista.add_child(_cartao(String(t[0]), String(t[1]), String(t[2])))

func _cartao(id: String, nome: String, texto: String) -> Control:
    var p := T.painel_do_proto(14)
    var linha := HBoxContainer.new()
    linha.add_theme_constant_override("separation", 16)
    p.add_child(linha)
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    col.add_theme_constant_override("separation", 4)
    linha.add_child(col)
    var titulo := T.rotulo(nome, T.NOME_ITEM, T.OURO_FORTE)
    col.add_child(titulo)
    var desc := T.rotulo(texto, T.CORPO, T.TEXTO_FRACO, true)
    col.add_child(desc)
    var estado := T.rotulo("", T.CORPO, T.TEXTO)
    col.add_child(estado)
    var subir := T.botao("Evoluir", T.PRIMARIO, 44.0)
    subir.custom_minimum_size.x = 150
    subir.pressed.connect(func():
        if _progresso: _progresso.subir_skill(id))
    var centro := CenterContainer.new()
    centro.add_child(subir)
    linha.add_child(centro)
    _linhas[id] = {"estado": estado, "botao": subir, "titulo": titulo}
    return p

func _pintar() -> void:
    if _progresso == null or _pontos == null: return
    var livres: int = _progresso.pontos_de_skill_disponiveis()
    _pontos.text = "%d ponto(s) de talento" % livres
    _pontos.add_theme_color_override("font_color", T.SUCESSO if livres > 0 else T.TEXTO_FRACO)
    for id in _linhas:
        var chave := String(id)
        var liberado: bool = _progresso.skill_desbloqueada(chave)
        var nivel: int = int(_progresso.niveis_skills.get(chave, 1))
        var teto: int = _progresso.NIVEL_MAXIMO_SKILL
        _linhas[id]["estado"].text = ("Nível %d / %d" % [nivel, teto]) if liberado \
            else "Bloqueado até o nível %d" % int(_progresso.NIVEIS_DESBLOQUEIO_SKILLS.get(chave, 1))
        _linhas[id]["estado"].add_theme_color_override("font_color",
            T.TEXTO if liberado else T.TEXTO_FRACO)
        _linhas[id]["titulo"].add_theme_color_override("font_color",
            T.OURO_FORTE if liberado else T.TEXTO_FRACO)
        _linhas[id]["botao"].disabled = not liberado or livres <= 0 or nivel >= teto
