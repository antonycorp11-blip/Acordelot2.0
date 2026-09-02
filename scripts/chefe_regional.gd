extends Node3D
class_name ChefeRegional

## Encontro persistente do Cavaleiro da Nota Silenciada. O cavaleiro existe no
## mapa, mas so pensa e agride depois de o jogador aceitar o desafio.

signal jogador_chegou(encontro: Node)
signal jogador_saiu(encontro: Node)

const BichoScript := preload("res://scripts/bicho.gd")
const CAMINHO_EMBLEMA := "res://models/emblema_cavaleiro.glb"
const T := preload("res://scripts/ui_tema.gd")
const ALCANCE_INTERACAO := 6.0
const RAIO_DA_ARENA := 48.0
const NOTAS := ["do", "re", "mi", "fa", "sol", "la", "si"]

var _jogador: Node3D
var _cavaleiro: CharacterBody3D
var _em_batalha := false
var _perto := false
var _tela: CanvasLayer
var _painel: Control
var _sorte := RandomNumberGenerator.new()
var _conteudo_carregado := false


func _ready() -> void:
    add_to_group("chefe_regional")
    _sorte.randomize()
    _jogador = get_tree().get_first_node_in_group("jogador") as Node3D
    if _jogador == null:
        _jogador = get_tree().get_first_node_in_group("player") as Node3D
    _montar_tela()


func _process(_delta: float) -> void:
    if not is_instance_valid(_jogador):
        _jogador = get_tree().get_first_node_in_group("jogador") as Node3D
        return
    var distancia := global_position.distance_to(_jogador.global_position)
    if distancia <= 95.0 and not _conteudo_carregado:
        _carregar_conteudo()
    var agora_perto := distancia <= ALCANCE_INTERACAO and not _em_batalha \
        and _conteudo_carregado
    if agora_perto != _perto:
        _perto = agora_perto
        if _perto: jogador_chegou.emit(self)
        else:
            jogador_saiu.emit(self)
            if not _em_batalha and _painel and _painel.visible:
                _fechar_modal()
    if _em_batalha and distancia > RAIO_DA_ARENA:
        _encerrar_por_afastamento()


func abrir_desafio() -> void:
    if _em_batalha:
        return
    if not _conteudo_carregado: _carregar_conteudo()
    _mostrar_modal(false, {})


func _carregar_conteudo() -> void:
    if _conteudo_carregado: return
    _conteudo_carregado = true
    _montar_altar()
    _repor_cavaleiro()


func _iniciar() -> void:
    _fechar_modal()
    _em_batalha = true
    _perto = false
    jogador_saiu.emit(self)
    if not is_instance_valid(_cavaleiro):
        _repor_cavaleiro()
    _cavaleiro.process_mode = Node.PROCESS_MODE_INHERIT
    _cavaleiro.set_physics_process(true)
    _cavaleiro.set_process(true)
    # Duas barras: cada forma deve durar o bastante para ler avisos e esquivar.
    var progresso := get_node_or_null("/root/Progresso")
    var ataque := 120.0
    var vida_heroi := 900.0
    if progresso:
        var ficha: Dictionary = progresso.estatisticas()
        ataque = float(ficha.get("ataque", ataque))
        vida_heroi = float(ficha.get("vida_maxima", vida_heroi))
    _cavaleiro.call("calibrar", maxf(ataque * 18.0, 3600.0), maxf(vida_heroi / 13.0, 36.0))
    var hud := get_tree().get_first_node_in_group("player_hud")
    if hud and hud.has_method("anunciar"):
        hud.anunciar("DESAFIO INICIADO — Cavaleiro da Nota Silenciada")


func _repor_cavaleiro() -> void:
    if is_instance_valid(_cavaleiro):
        _cavaleiro.queue_free()
    var novo := BichoScript.new()
    novo.monster_type = 6
    novo.raio_de_atencao = 34.0
    novo.recompensa_controlada_externamente = true
    add_child(novo)
    novo.position = Vector3.ZERO
    novo.call("tornar_cavaleiro_chefe")
    novo.derrotado.connect(_ao_derrotar)
    novo.process_mode = Node.PROCESS_MODE_DISABLED
    _cavaleiro = novo


func _encerrar_por_afastamento() -> void:
    _em_batalha = false
    _repor_cavaleiro()
    var hud := get_tree().get_first_node_in_group("player_hud")
    if hud and hud.has_method("anunciar"):
        hud.anunciar("O silêncio recompôs o Cavaleiro — desafio encerrado")


func _ao_derrotar(_inimigo: Node) -> void:
    if not _em_batalha:
        return
    _em_batalha = false
    var ganhos := _sortear_recompensas()
    var progresso := get_node_or_null("/root/Progresso")
    if progresso:
        progresso.recompensar_batalha(0, ganhos)
    _mostrar_modal(true, ganhos)


func _sortear_recompensas() -> Dictionary:
    var emblemas := 1
    if _sorte.randf() < 0.32: emblemas += 1
    if _sorte.randf() < 0.08: emblemas += 1
    var ganhos := {
        "emblema_nota_silenciada": emblemas,
        "claves": _sorte.randi_range(750, 1150),
        "fragmento_corrompido_" + String(NOTAS.pick_random()): _sorte.randi_range(8, 16),
    }
    if _sorte.randf() < 0.72: ganhos["pocao_cura"] = _sorte.randi_range(1, 2)
    var rolagem := _sorte.randf()
    ganhos["partitura_magistral" if rolagem < 0.10 else (
        "partitura_harmonica" if rolagem < 0.48 else "partitura_menor")] = 1
    return ganhos


func _montar_tela() -> void:
    _tela = CanvasLayer.new()
    _tela.layer = 130
    add_child(_tela)
    var fundo := ColorRect.new()
    fundo.color = Color(0.005, 0.012, 0.035, 0.91)
    fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
    fundo.visible = false
    _tela.add_child(fundo)
    _painel = fundo


func _mostrar_modal(vitoria: bool, ganhos: Dictionary) -> void:
    for filho in _painel.get_children(): filho.queue_free()
    _painel.visible = true
    var caixa := VBoxContainer.new()
    caixa.set_anchors_preset(Control.PRESET_CENTER)
    caixa.offset_left = -390.0; caixa.offset_right = 390.0
    caixa.offset_top = -265.0; caixa.offset_bottom = 265.0
    caixa.add_theme_constant_override("separation", 16)
    _painel.add_child(caixa)
    var titulo := T.rotulo("VITÓRIA" if vitoria else "CAVALEIRO DA NOTA SILENCIADA", T.TITULO_PAGINA)
    titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caixa.add_child(titulo)
    var texto := T.rotulo("A segunda forma rompe o selo e cobre a armadura de ressonância.\nDerrote as duas barras antes que o silêncio feche a arena." if not vitoria else "A nota aprisionada voltou a soar. Recompensas recebidas:", T.CORPO, T.TEXTO_FRACO, true)
    texto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    caixa.add_child(texto)
    var drops := VBoxContainer.new(); drops.add_theme_constant_override("separation", 8); caixa.add_child(drops)
    if vitoria:
        for id in ganhos: _linha_drop(drops, String(id), int(ganhos[id]), false)
    else:
        _linha_drop(drops, "emblema_nota_silenciada", 1, true)
        _linha_drop(drops, "claves", 750, true)
        _linha_drop(drops, "partitura_harmonica", 1, true)
        _linha_drop(drops, "fragmento_corrompido_do", 8, true)
        _linha_drop(drops, "pocao_cura", 1, true)
    caixa.add_child(T.espaco(0))
    var botao := T.botao("CONTINUAR" if vitoria else "ACEITAR DESAFIO", T.PRIMARIO, 56.0)
    botao.pressed.connect(_fechar_e_repor if vitoria else _iniciar)
    caixa.add_child(botao)
    if not vitoria:
        var cancelar := T.botao("AGORA NÃO", T.SECUNDARIO, 46.0)
        cancelar.pressed.connect(_fechar_modal); caixa.add_child(cancelar)


func _linha_drop(pai: Control, id: String, quantidade: int, possivel: bool) -> void:
    var nomes := {"emblema_nota_silenciada":"Emblema da Nota Silenciada", "claves":"Claves",
        "partitura_menor":"Partitura Menor", "partitura_harmonica":"Partitura Harmônica",
        "partitura_magistral":"Partitura Magistral", "pocao_cura":"Poção de Cura"}
    var nome := str(nomes.get(id, id.replace("_", " ").capitalize()))
    var linha := HBoxContainer.new()
    linha.alignment = BoxContainer.ALIGNMENT_CENTER
    linha.add_theme_constant_override("separation", 12)
    if id == "emblema_nota_silenciada":
        var icone := TextureRect.new()
        icone.texture = load("res://textures/items/emblema_nota_silenciada.png")
        icone.custom_minimum_size = Vector2(52, 52)
        icone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        linha.add_child(icone)
    var rotulo := T.rotulo(("Possível  ·  " if possivel else "") + nome + "  ×  " + str(quantidade) + ("+" if possivel else ""), T.BOTAO, T.OURO if id == "emblema_nota_silenciada" else T.TEXTO)
    rotulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    linha.add_child(rotulo)
    pai.add_child(linha)


func _fechar_modal() -> void:
    _painel.visible = false


func _fechar_e_repor() -> void:
    _fechar_modal()
    _repor_cavaleiro()


func _montar_altar() -> void:
    var base := MeshInstance3D.new()
    var cilindro := CylinderMesh.new(); cilindro.top_radius = 2.4; cilindro.bottom_radius = 2.7; cilindro.height = 0.45
    var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.09, 0.07, 0.15); mat.metallic = 0.35; mat.roughness = 0.6
    cilindro.material = mat; base.mesh = cilindro; base.position.y = -0.22; add_child(base)
    var marca := (load(CAMINHO_EMBLEMA) as PackedScene).instantiate() as Node3D
    # O arquivo mede 0,98 m de altura; 1,4x o deixa legível sem virar monumento.
    marca.position = Vector3(0, 0.45, -3.0); marca.scale = Vector3.ONE * 1.4
    add_child(marca)
    var luz := OmniLight3D.new(); luz.light_color = Color(0.55, 0.35, 1.0); luz.light_energy = 2.0; luz.omni_range = 10.0; luz.shadow_enabled = false; luz.position.y = 2.0; add_child(luz)
    var nome := Label3D.new(); nome.text = "DESAFIO REGIONAL\nCavaleiro da Nota Silenciada"; nome.font_size = 38; nome.outline_size = 8; nome.billboard = BaseMaterial3D.BILLBOARD_ENABLED; nome.no_depth_test = true; nome.position.y = 3.4; add_child(nome)
