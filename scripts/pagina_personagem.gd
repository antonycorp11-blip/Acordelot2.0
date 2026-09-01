extends Control
class_name PaginaPersonagem
## A FICHA DO AKLES, no formato do protótipo: atributos a esquerda, o herói de
## verdade no palco do meio, combate a direita.
##
## O palco nao e ilustracao: e o `heroi_base.fbx` do jogo, o mesmo modelo que
## anda no mundo, renderizado num SubViewport proprio com luz e camera so dele.
## Foi a correcao que o proprio jogo pediu — retrato desenhado nunca e o
## personagem, e ver a armadura que voce esta usando e metade da razao de abrir
## uma ficha. O viewport so desenha enquanto a pagina esta a mostra.
const T := preload("res://scripts/ui_tema.gd")

const NOMES := {"forca": "Força", "destreza": "Destreza", "vitalidade": "Vitalidade",
    "ressonancia": "Ressonância", "percepcao": "Percepção"}
## Altura em que o modelo e normalizado dentro do palco, em metros.
const ALTURA_NO_PALCO := 1.75
const GIRO_DO_PALCO := 0.35

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
var _palco: SubViewport
var _modelo: Node3D
var _nivel_no_palco: Label


func _ready() -> void:
    _progresso = get_node_or_null("/root/Progresso")
    _montar()
    if _progresso and not _progresso.alterado.is_connected(_pintar):
        _progresso.alterado.connect(_pintar)
    set_process(false)


func ao_abrir() -> void:
    _pintar()
    set_process(true)
    if _palco:
        _palco.render_target_update_mode = SubViewport.UPDATE_ALWAYS


func ao_fechar() -> void:
    set_process(false)
    if _palco:
        _palco.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _process(delta: float) -> void:
    if _modelo:
        _modelo.rotate_y(delta * GIRO_DO_PALCO)


func _montar() -> void:
    var linha := HBoxContainer.new()
    linha.set_anchors_preset(Control.PRESET_FULL_RECT)
    linha.add_theme_constant_override("separation", 14)
    add_child(linha)

    # ------------------------------------------------------- atributos
    var esq := T.painel_do_proto(16)
    esq.custom_minimum_size.x = 330
    linha.add_child(esq)
    var ce := VBoxContainer.new()
    ce.add_theme_constant_override("separation", 6)
    esq.add_child(ce)
    ce.add_child(T.cabeca_de_painel("Talento bruto", "Atributos"))
    _pontos = T.rotulo_simples("", 17, T.GANHO)
    ce.add_child(_pontos)
    ce.add_child(T.espaco(6))
    for id in NOMES:
        var l := _linha_de_atributo(String(id))
        l.size_flags_vertical = Control.SIZE_EXPAND_FILL
        ce.add_child(l)

    # ------------------------------------------------------------ palco
    var meio := T.painel_do_proto(14)
    meio.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    linha.add_child(meio)
    var cm := VBoxContainer.new()
    cm.add_theme_constant_override("separation", 4)
    meio.add_child(cm)

    var topo := HBoxContainer.new()
    topo.add_theme_constant_override("separation", 12)
    cm.add_child(topo)
    var ident := VBoxContainer.new()
    ident.add_theme_constant_override("separation", 0)
    ident.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    topo.add_child(ident)
    ident.add_child(T.sobrancelha("Maestro da Vigília"))
    ident.add_child(T.titulo_do_proto("Akles", 34))
    _nivel_no_palco = T.rotulo_simples("", 17, T.SOBRANCELHA)
    _nivel_no_palco.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
    topo.add_child(_nivel_no_palco)

    cm.add_child(_montar_palco())

    _barra = T.barra(Color(0.30, 0.58, 0.92), Color(0.42, 0.72, 1.0), 10.0)
    cm.add_child(_barra)
    _xp = T.rotulo_simples("", 15, T.SOBRANCELHA)
    _xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    cm.add_child(_xp)

    # --------------------------------------------------------- combate
    var dir := T.painel_do_proto(16)
    dir.custom_minimum_size.x = 340
    linha.add_child(dir)
    var cd := VBoxContainer.new()
    cd.add_theme_constant_override("separation", 6)
    dir.add_child(cd)
    cd.add_child(T.cabeca_de_painel("Evolução atual", "Em combate"))
    _nivel = T.rotulo_simples("", 19, T.CREME)
    cd.add_child(_nivel)
    _poder = T.rotulo_simples("", 40, Color(0.941, 0.745, 0.361))
    _poder.add_theme_font_override("font", T.fonte_titulo())
    cd.add_child(_poder)
    cd.add_child(T.sobrancelha("Poder de luta"))
    cd.add_child(T.espaco(8))
    _stats = VBoxContainer.new()
    _stats.add_theme_constant_override("separation", 0)
    _stats.size_flags_vertical = Control.SIZE_EXPAND_FILL
    cd.add_child(_stats)
    _acao = T.botao("Subir nível", T.PRIMARIO, 54.0)
    _acao.pressed.connect(_agir)
    cd.add_child(_acao)


## O PALCO. Mundo proprio, luz propria, camera propria — nada do mundo do jogo
## entra aqui, e nada daqui aparece la.
func _montar_palco() -> Control:
    var caixa := SubViewportContainer.new()
    caixa.stretch = true
    caixa.size_flags_vertical = Control.SIZE_EXPAND_FILL
    caixa.custom_minimum_size.y = 260
    caixa.mouse_filter = Control.MOUSE_FILTER_IGNORE

    _palco = SubViewport.new()
    _palco.own_world_3d = true
    _palco.world_3d = World3D.new()
    _palco.transparent_bg = true
    _palco.render_target_update_mode = SubViewport.UPDATE_DISABLED
    caixa.add_child(_palco)

    var ambiente := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.0, 0.0, 0.0, 0.0)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.60, 0.68, 0.85)
    env.ambient_light_energy = 1.35
    ambiente.environment = env
    _palco.add_child(ambiente)

    var chave := DirectionalLight3D.new()
    chave.light_energy = 2.1
    chave.rotation_degrees = Vector3(-38.0, 148.0, 0.0)
    chave.shadow_enabled = false
    _palco.add_child(chave)

    var preenchimento := OmniLight3D.new()
    preenchimento.light_color = Color(0.45, 0.68, 1.0)
    preenchimento.light_energy = 2.4
    preenchimento.omni_range = 6.0
    preenchimento.position = Vector3(-1.6, 1.4, 1.8)
    preenchimento.shadow_enabled = false
    _palco.add_child(preenchimento)

    var pivo := Node3D.new()
    _palco.add_child(pivo)
    _modelo = pivo

    var cena := load("res://personagem/heroi_base.fbx")
    if cena:
        var corpo: Node3D = (cena as PackedScene).instantiate()
        pivo.add_child(corpo)
        var caixa_do_corpo := _medir(corpo)
        # O LIMIAR PRECISA CABER NO MODELO, NAO O CONTRARIO.
        #
        # O FBX vem do Mixamo em centimetros: o heroi inteiro mede 0,00995 de
        # altura em unidades de cena. Eu exigia "maior que 0,01" para aceitar a
        # medida — nove milesimos a menos que o necessario —, entao a escala
        # nunca era aplicada, o boneco ficava do tamanho de um grao de arroz na
        # origem e o palco parecia vazio.
        if caixa_do_corpo.size.y > 0.0001:
            var fator: float = ALTURA_NO_PALCO / caixa_do_corpo.size.y
            corpo.scale = Vector3.ONE * fator
            corpo.position = Vector3(
                -(caixa_do_corpo.position.x + caixa_do_corpo.size.x * 0.5) * fator,
                -caixa_do_corpo.position.y * fator,
                -(caixa_do_corpo.position.z + caixa_do_corpo.size.z * 0.5) * fator)
        var tocador: AnimationPlayer = corpo.find_child("AnimationPlayer", true, false)
        var biblioteca: AnimationLibrary = load("res://personagem/heroi_anims.res")
        if tocador and biblioteca:
            tocador.add_animation_library("heroi", biblioteca)
            if tocador.has_animation("heroi/parado"):
                tocador.play("heroi/parado")

    # A CAMERA MIRA DEPOIS DE ENTRAR NA ARVORE. `look_at` trabalha em
    # coordenadas globais, e fora da arvore nao existe global nenhum: mirar
    # antes de `add_child` nao faz nada e a camera fica olhando para o padrao.
    var camera := Camera3D.new()
    camera.fov = 30.0
    camera.current = true
    _palco.add_child(camera)
    camera.look_at_from_position(Vector3(0.0, ALTURA_NO_PALCO * 0.54, 3.0),
        Vector3(0.0, ALTURA_NO_PALCO * 0.50, 0.0), Vector3.UP)
    return caixa


func _medir(raiz: Node3D) -> AABB:
    var total := AABB()
    var achou := false
    for malha in raiz.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        var local: AABB = mi.get_aabb()
        var no: Node3D = mi
        while no != null and no != raiz:
            local = no.transform * local
            no = no.get_parent() as Node3D
        total = local if not achou else total.merge(local)
        achou = true
    return total


func _linha_de_atributo(id: String) -> Control:
    var l := HBoxContainer.new()
    l.add_theme_constant_override("separation", 10)
    l.custom_minimum_size.y = 44
    var nome := T.rotulo_simples(String(NOMES[id]), 19, Color(0.741, 0.686, 0.576))
    nome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_child(nome)
    var valor := T.rotulo_simples("", 22, T.CREME)
    valor.custom_minimum_size.x = 52
    valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    valor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.add_child(valor)
    var mais := T.botao("+", T.SECUNDARIO, 38.0)
    mais.custom_minimum_size.x = 46
    mais.size_flags_vertical = Control.SIZE_SHRINK_CENTER
    mais.pressed.connect(func():
        if _progresso: _progresso.investir_atributo(id))
    l.add_child(mais)
    _linhas[id] = {"valor": valor, "mais": mais}
    return l


func _agir() -> void:
    if _progresso == null: return
    var antes: int = _progresso.nivel
    if _progresso.esta_em_trava_de_ascensao(): _progresso.tentar_ascensao()
    else: _progresso.subir_nivel()
    if _progresso.nivel > antes:
        var casca := get_tree().root.find_child("UiShell", true, false)
        if casca and casca.has_method("avisar"):
            casca.avisar("Harmonia fortalecida", "Akles alcançou o nível %d" % _progresso.nivel)


func _pintar() -> void:
    if _progresso == null: return
    var falta := float(_progresso.xp_para_nivel())
    _nivel.text = "Nível %d" % _progresso.nivel
    _nivel_no_palco.text = "Nível %d" % _progresso.nivel
    _xp.text = "%d / %d XP" % [_progresso.experiencia, int(falta)]
    var destino: float = clampf(float(_progresso.experiencia) / maxf(falta, 1.0), 0.0, 1.0)
    if is_inside_tree() and absf(destino - _barra.value) > 0.001:
        if _corrida_da_barra and _corrida_da_barra.is_valid():
            _corrida_da_barra.kill()
        _corrida_da_barra = create_tween()
        _corrida_da_barra.tween_property(_barra, "value", destino, 0.28) \
            .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    else:
        _barra.value = destino

    _pontos.text = "%d ponto(s) a distribuir" % _progresso.pontos_de_atributo
    _pontos.add_theme_color_override("font_color",
        T.GANHO if _progresso.pontos_de_atributo > 0 else T.SOBRANCELHA)
    _poder.text = "%d" % int(_progresso.poder_de_luta_detalhado()["total"])
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
    for par in [["Vida", "%d" % int(e["vida_maxima"])], ["Ataque", "%d" % int(e["ataque"])],
            ["Defesa", "%d" % int(e["defesa"])], ["Crítico", "%.1f%%" % float(e["critico"])],
            ["Dano crítico", "%.0f%%" % float(e["dano_critico"])],
            ["Poder harmônico", "%d" % int(e["poder_harmonico"])]]:
        var l := T.linha_de_status(String(par[0]), String(par[1]))
        l.size_flags_vertical = Control.SIZE_EXPAND_FILL
        _stats.add_child(l)
