extends Node3D

## Pelo caminho, nao pelo nome global: o nome so existe depois que o editor
## varre o projeto, e isso quebra exportacao limpa.
const MIRA := preload("res://scripts/botao_de_mira.gd")
const DialogoScript := preload("res://scripts/dialogo.gd")
## Pelo caminho, nao pelo nome global: o nome so existe depois que o editor
## varre o projeto, e isso quebra exportacao limpa.
const AquecimentoScript := preload("res://scripts/aquecimento.gd")
const AjustesScript := preload("res://scripts/ajustes.gd")
const UiShellScript := preload("res://scripts/ui_shell.gd")
const PAGINAS := [
    ["personagem", "Personagem", "res://textures/ui/kit/nav/personagem.png",
     preload("res://scripts/pagina_personagem.gd")],
    ["talentos", "Talentos", "res://textures/ui/kit/nav/talentos.png",
     preload("res://scripts/pagina_talentos.gd")],
    ["sintese", "Síntese", "res://textures/ui/kit/nav/melodia.png",
     preload("res://scripts/pagina_sintese.gd")],
    # Temporariamente no HUD para teste. Quando o Observatório Harmônico entrar
    # no mapa, esta mesma página será aberta pela interação do cenário.
    ["forja_escalas", "Forja", "res://textures/ui/kit/nav/lira.png",
     preload("res://scripts/pagina_forja_escalas.gd")],
    ["inventario", "Inventário", "res://textures/ui/kit/nav/inventario.png",
     preload("res://scripts/pagina_inventario.gd")],
    ["missoes", "Missões", "res://textures/ui/kit/nav/missoes.png",
     preload("res://scripts/pagina_missoes.gd")],
    ["mapa", "Mapa", "res://textures/ui/kit/nav/mapa.png",
     preload("res://scripts/pagina_mapa.gd")],
    ["loja", "Loja", "res://textures/ui/kit/nav/loja.png",
     preload("res://scripts/pagina_loja.gd")],
    ["ecos", "Ecos", "res://textures/ui/kit/nav/lira.png",
     preload("res://scripts/pagina_ecos.gd")],
]
const EcoDoNascenteCena := preload("res://scenes/ecos/EcoDoNascente.tscn")
const RessonanciaHUDScript := preload("res://scripts/ressonancia_hud.gd")
const CelebracaoScript := preload("res://scripts/celebracao_harmonica.gd")
const AreaSeguraUIScript := preload("res://scripts/area_segura_ui.gd")
const DesempenhoAdaptativoScript := preload("res://scripts/desempenho_adaptativo.gd")
const DungeonCavernaScript := preload("res://scripts/dungeon_caverna.gd")
const GeradorDeBichosScript := preload("res://scripts/gerador_de_bichos.gd")
const CeuCompatibilidadeScript := preload("res://scripts/ceu_compatibilidade.gd")
const PortalCavernaScript := preload("res://scripts/portal_caverna.gd")
const ChefeRegionalScript := preload("res://scripts/chefe_regional.gd")
var _gerador_bichos: GeradorDeBichos = null
const FRAMES_ECOS := {
    "do": preload("res://resources/eco_do_nascente_frames.tres"),
    "do_sustenido": preload("res://resources/eco_ambar_frames.tres"),
    "re": preload("res://resources/eco_rubi_frames.tres"),
    "re_sustenido": preload("res://resources/eco_cervo_dourado_frames.tres"),
    "mi": preload("res://resources/eco_folha_frames.tres"),
    "fa": preload("res://resources/eco_agua_frames.tres"),
    "fa_sustenido": preload("res://resources/eco_clave_azul_frames.tres"),
    "sol": preload("res://resources/eco_safira_frames.tres"),
    "sol_sustenido": preload("res://resources/eco_ametista_frames.tres"),
    "la": preload("res://resources/eco_draconico_frames.tres"),
    "la_sustenido": preload("res://resources/eco_celeste_frames.tres"),
}

## A NPC ao alcance, se houver. E ela que decide o que o botao de ataque faz.
var _npc_perto: Node = null
## A boca de caverna ao alcance, se houver. Divide o mesmo botao com a conversa.
var _portal_perto: Node = null
var _chefe_perto: Node = null
var _btn_ataque: Node = null
var _dialogo: Node = null
var _shell: CanvasLayer = null
var _celebracao: Control = null
var _eco_companheiro: Node3D = null
var _eco_companheiro_id := ""
var _btn_skill_eco: Button = null
var _rotulo_cooldown_eco: Label = null
var _efeito_skill_eco: MeshInstance3D = null
var _cooldown_skill_eco := 0.0
var _hud_ressonancia = null
var _eco_captura: Node3D = null
var _ressonando := false
var _progresso_ressonancia := 0.0
var _ate_buscar_eco := 0.0
var _sorte_captura := RandomNumberGenerator.new()

@onready var _player: CharacterBody3D = $Player
@onready var _zone_manager: ZoneManager = $ZoneManager

func _ready() -> void:
    var hud_vida: Node = find_child("PlayerHUD", true, false)

    # Detalhe visível também no Web/Compatibility: duas MultiMeshes para
    # nuvens/estrelas e uma lua, sem shader de céu incompatível.
    var ceu := CeuCompatibilidadeScript.new()
    ceu.name = "CeuVivoCompatibilidade"
    ceu.ciclo = $CicloDiaNoite
    add_child(ceu)

    # A DG é isolada do mapa por zonas e acessada por um único botão no HUD.
    # Nasce uma vez no carregamento para não montar modelos durante a partida.
    var dungeon := DungeonCavernaScript.new()
    dungeon.name = "DungeonCaverna"
    add_child(dungeon)

    # Os monstros agora pertencem a ninhos planejados em cada região.
    # O antigo gerador móvel criava seis Shikers ao redor do herói além dos
    # ninhos já carregados, fazendo uma horda reaparecer e perseguir sem parar.
    _gerador_bichos = null
    
    _btn_ataque = find_child("BtnAtaque", true, false)
    if _btn_ataque:
        # UM botao, duas funcoes. Perto de alguem ele conversa; longe, ataca.
        # Um segundo botao so para falar ficaria apagado 95% do jogo e roubaria
        # canto de tela num celular que ja tem seis controles.
        _btn_ataque.pressed.connect(func():
            if _npc_perto != null:
                _conversar()
            elif _chefe_perto != null:
                _chefe_perto.abrir_desafio()
            elif _portal_perto != null:
                _entrar_pelo_portal()
            elif _player and _player.has_method("atacar"):
                _player.atacar()
        )

    # Assa os shaders enquanto o mapa ainda esta nascendo. Sem isto, a primeira
    # aparicao de cada coisa — Shiker, Mirella, skill — para o jogo por um
    # instante para compilar o shader dela.
    if OS.get_cmdline_user_args().has("--shot"):
        _tirar_print()

    var forno: Node3D = AquecimentoScript.new()
    forno.name = "Aquecimento"
    add_child(forno)

    # Cada zona nova traz os seus moradores: reconecta a cada troca.
    if _zone_manager:
        _zone_manager.zone_changed.connect(func(z):
            # A trilha muda com o lugar: cidade em tom maior e mais presente,
            # campo mais espacado. A caverna troca sozinha ao entrar.
            var trilha := get_node_or_null("/root/Trilha")
            if trilha:
                var urbana: bool = str(z.get("biome", "")) == "cidade" \
                    or str(z.get("layout_id", "")) != ""
                trilha.definir_clima("cidade" if urbana else "mundo")
            if _gerador_bichos:
                _gerador_bichos.definir_zona(z)
            var diario_zona := get_node_or_null("/root/Diario")
            if diario_zona:
                diario_zona.registrar_visita(str(z.get("id", "")))
            registrar_npcs()
            _sincronizar_eco_companheiro(true)
            _eco_captura = null
            _progresso_ressonancia = 0.0)
        if _gerador_bichos:
            _gerador_bichos.definir_zona(_zone_manager.zona_atual())

    # A caixa de conversa nasce com o mundo, escondida.
    _dialogo = DialogoScript.new()
    _dialogo.name = "Dialogo"
    add_child(_dialogo)
    _dialogo.terminou.connect(func():
        if _player:
            _player.set_physics_process(true)
        if _npc_perto and _npc_perto.has_method("voltar_a_rotina"):
            _npc_perto.voltar_a_rotina()
        _pintar_botao())
        
    # A mochila do PlayerHUD fica no canto de cima, atras do minimapa no
    # celular — na pratica ninguem achava. Este e o botao que se ve.
    # NAO ha botao proprio de inventario: quem abre e a mochila do PlayerHUD, na
    # coluna de utilitarios do canto de cima. Ter dois botoes para a mesma tela
    # so aumentava a HUD — e o que faltava era a mochila aparecer no lugar
    # certo, coisa que a ancoragem corrigida resolveu.

    var btn_voo := find_child("BtnVoo", true, false)
    if btn_voo:
        btn_voo.pressed.connect(func():
            if _player and _player.has_method("alternar_voo"):
                _player.alternar_voo()
        )

    _acomodar_controles_do_polegar()
    get_viewport().size_changed.connect(_acomodar_controles_do_polegar)
        
    # A mochila e a engrenagem sao do kit novo e nascem dentro do PlayerHUD, que
    # e quem sabe onde a arte encaixa. Aqui so se diz o que elas fazem.
    if hud_vida and hud_vida.has_signal("mochila_pedida"):
        hud_vida.mochila_pedida.connect(func(): _shell.abrir("inventario"))
    # A ESCALA DO MUNDO, escolhida pelo jogador. Aplicada antes de qualquer
    # tela existir, para o primeiro quadro ja sair no tamanho certo.
    AjustesScript.aplicar_guardado(get_tree())
    var adaptativo := DesempenhoAdaptativoScript.new()
    adaptativo.name = "DesempenhoAdaptativo"
    add_child(adaptativo)
    var ajustes: CanvasLayer = AjustesScript.new()
    ajustes.name = "Ajustes"
    add_child(ajustes)

    # UM SHELL, OITO PAGINAS.
    #
    # Antes cada tela era uma CanvasLayer com fundo, moldura e botao de fechar
    # proprios, e abrir uma destruia a outra — junto com a barra de navegacao de
    # baixo, que existe justamente para trocar de aba. Agora a moldura, o
    # cabecalho, o fechar e a navbar sao um so e nao piscam; trocar de aba troca
    # apenas o miolo, sem construir nada.
    _shell = UiShellScript.new()
    _shell.name = "UiShell"
    add_child(_shell)
    for p in PAGINAS:
        var pagina: Control = p[3].new()
        pagina.name = "Pagina_" + String(p[0])
        _shell.registrar(String(p[0]), String(p[1]), String(p[2]), pagina)
    _shell.abrir("inventario")
    _shell.visible = false

    var progresso := get_node_or_null("/root/Progresso")
    _criar_botao_skill_eco()
    _criar_efeito_skill_eco()
    _hud_ressonancia = RessonanciaHUDScript.new()
    _hud_ressonancia.name = "HUDRessonancia"
    add_child(_hud_ressonancia)
    var hud_da_vida := get_tree().get_first_node_in_group("player_hud")
    if hud_da_vida and hud_da_vida.has_signal("caiu") \
            and not hud_da_vida.caiu.is_connected(_ao_cair):
        hud_da_vida.caiu.connect(_ao_cair)
    _ultimo_lugar_seguro = _player.global_position if _player else Vector3.ZERO

    _hud_ressonancia.ressoar_iniciado.connect(func(): _ressonando = true)
    _hud_ressonancia.ressoar_parado.connect(func(): _ressonando = false)
    _sorte_captura.randomize()
    if progresso:
        if not progresso.alterado.is_connected(_sincronizar_eco_companheiro):
            progresso.alterado.connect(_sincronizar_eco_companheiro)
        if not progresso.alterado.is_connected(_atualizar_botoes_skill):
            progresso.alterado.connect(_atualizar_botoes_skill)
        call_deferred("_sincronizar_eco_companheiro")
        call_deferred("_atualizar_botoes_skill")

    if hud_vida and hud_vida.has_signal("config_pedida"):
        hud_vida.config_pedida.connect(func(): ajustes.mostrar(true))

    if hud_vida and hud_vida.has_signal("missoes_pedidas"):
        hud_vida.missoes_pedidas.connect(func(): _shell.abrir("missoes"))
        
    # Conexão dos 3 Botões de Habilidades (Skills)
    var btn_skill1 := find_child("BtnSkill1", true, false)
    if btn_skill1:
        btn_skill1.pressed.connect(func():
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(1)
        )
        _criar_capa_de_recarga(btn_skill1 as Control, 1)

    var btn_skill2 := find_child("BtnSkill2", true, false)
    if btn_skill2:
        btn_skill2.pressed.connect(func():
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(2)
        )
        _criar_capa_de_recarga(btn_skill2 as Control, 2)
        
    # O raio ganha mira por arrasto, no gesto do Brawl Stars.
    #
    # E a unica das tres em que errar o alvo custa caro, e a mira automatica
    # escolhe sozinha quando ha mais de um inimigo perto — sem o jogador poder
    # discordar. As outras duas seguem no toque simples, que basta para elas.
    var btn_skill3 := find_child("BtnSkill3", true, false)
    if btn_skill3 and btn_skill3 is Control:
        var alvo := btn_skill3 as Control
        var mira: Control = MIRA.new()
        mira.set_anchors_preset(Control.PRESET_FULL_RECT)
        alvo.add_child(mira)
        # A arte continua sendo a do botao embaixo; a mira so desenha a seta.
        if alvo is TextureButton and alvo.texture_normal:
            mira.definir_arte(null)
        mira.mirando.connect(func(direcao: Vector2):
            if _player and _player.has_method("atualizar_mira_skill"):
                _player.atualizar_mira_skill(3, direcao)
        )
        mira.mira_cancelada.connect(func():
            if _player and _player.has_method("cancelar_mira_skill"):
                _player.cancelar_mira_skill(3)
        )
        mira.cancelado.connect(func():
            if _player and _player.has_method("cancelar_mira_skill"):
                _player.cancelar_mira_skill(3)
        )
        mira.disparar.connect(func(direcao: Vector2):
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(3, direcao)
        )
        _criar_capa_de_recarga(alvo, 3)
        
    var joystick := find_child("VirtualJoystick", true, false)
    if joystick:
        joystick.add_to_group("virtual_joystick")

    # Depois do mundo montado: o portal precisa do relevo para saber onde e o
    # chao, e o relevo so responde certo com a grade de celulas ja carregada.
    call_deferred("_semear_portais")
    call_deferred("_semear_cavaleiro_regional")


## O AVISO DE PROGRESSO, que nao existia em lugar nenhum.
##
## Subir de nivel, fechar uma tarefa do dia e fechar o dia inteiro aconteciam em
## silencio: o numero mudava numa tela que o jogador nao estava olhando. O sinal
## `nivel_subiu` existia desde sempre e NINGUEM escutava.
##
## O cartao e o mesmo `CelebracaoHarmonica` que as telas de ficha e de sintese ja
## usam — paineis e Tween, sem shader nem particula, igual no navegador. Fazer um
## segundo aviso do zero seria manter dois estilos de comemoracao no mesmo jogo.
func _montar_celebracao() -> void:
    var hud := get_node_or_null("HUD")
    if hud == null:
        return
    _celebracao = CelebracaoScript.new()
    _celebracao.name = "Celebracao"
    hud.add_child(_celebracao)

    var progresso := get_node_or_null("/root/Progresso")
    if progresso:
        progresso.nivel_subiu.connect(func(novo: int):
            _celebracao.mostrar_evento("NÍVEL %d" % novo,
                "+3 pontos de atributo  •  +1 ponto de talento",
                Color(1.0, 0.82, 0.35)))

    var diario := get_node_or_null("/root/Diario")
    if diario:
        diario.missao_concluida.connect(func(missao: Dictionary):
            _celebracao.mostrar_evento("TAREFA CUMPRIDA",
                "%s  •  +%d Claves" % [missao["titulo"], diario.CLAVES_POR_MISSAO],
                Color(0.44, 0.86, 0.52)))
        diario.dia_completo.connect(func():
            _celebracao.mostrar_evento("DIÁRIO COMPLETO",
                "+%d Claves  •  +1 Partitura Menor" % diario.CLAVES_DO_DIA,
                Color(0.62, 0.72, 1.0)))


## OS CONTROLES DO POLEGAR, todos com o mesmo recuo do aparelho.
##
## O botao de voo e a roda de combate vinham da cena com margem fixa: 36 px da
## esquerda e 15 px da borda de baixo e da direita. Quando o direcional passou a
## respeitar o recuo do aparelho, ele subiu e andou para dentro — e encontrou o
## botao de voo, que continuou onde estava. Sobrepunham 64 por 9 pixels em toda
## proporcao de tela que eu medi.
##
## A roda de combate tinha o mesmo defeito pelo outro lado: 15 px do canto
## inferior direito e exatamente a faixa da barra de gestos e do canto
## arredondado do celular.
func _acomodar_controles_do_polegar() -> void:
    var tela := get_viewport().get_visible_rect().size
    var btn_voo := find_child("BtnVoo", true, false) as Control
    if btn_voo:
        # Empilhado acima do direcional, que ocupa 210 px de altura.
        AreaSeguraUIScript.encostar_no_canto(btn_voo, Vector2(64, 64), tela,
            true, true, 218.0)
    var combate := find_child("BotoesCombate", true, false) as Control
    if combate:
        AreaSeguraUIScript.encostar_no_canto(combate, Vector2(255, 255), tela,
            false, true)



func _abrir_tela_missoes() -> void:
    _shell.abrir("missoes")




func _abrir_mapa_do_reino() -> void:
    _shell.abrir("mapa")




func _abrir_tela_ecos() -> void:
    _shell.abrir("ecos")




func _abrir_tela_skills() -> void:
    _shell.abrir("talentos")



func _atualizar_botoes_skill() -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return
    for dados in [["BtnSkill1", "skill_1"], ["BtnSkill2", "skill_2"], ["BtnSkill3", "skill_3"]]:
        var botao := find_child(str(dados[0]), true, false) as BaseButton
        if botao:
            botao.disabled = not progresso.skill_desbloqueada(str(dados[1]))
            botao.modulate = Color.WHITE if not botao.disabled else Color(0.30, 0.32, 0.38, 0.72)


func _sincronizar_eco_companheiro(_forcar := false) -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return
    var dados: Dictionary = progresso.eco_equipado
    var id := str(dados.get("id", ""))
    if not _forcar and id == _eco_companheiro_id and is_instance_valid(_eco_companheiro):
        return
    if is_instance_valid(_eco_companheiro):
        _eco_companheiro.queue_free()
    _eco_companheiro = null
    _eco_companheiro_id = id
    var caminho := str(dados.get("arte", ""))
    var frames: SpriteFrames = FRAMES_ECOS.get(id) as SpriteFrames
    if id.is_empty() or caminho.is_empty() or frames == null:
        _atualizar_botao_skill_eco()
        return
    var eco := EcoDoNascenteCena.instantiate()
    eco.name = "EcoEquipado_" + id
    eco.usar_particulas = false
    eco.altura_aparente_m = 0.70
    var sprite := eco.get_node("Visual/AnimatedSprite3D") as AnimatedSprite3D
    sprite.sprite_frames = frames
    sprite.visibility_range_end = 34.0
    add_child(eco)
    eco.global_position = _player.global_position + Vector3(1.2, 0.2, 1.0)
    eco.definir_terreno(find_child("ZoneBuilder", true, false))
    eco.definir_seguidor(_player)
    _eco_companheiro = eco
    _atualizar_botao_skill_eco()


## A ESPERA PRECISA APARECER NO BOTAO.
##
## Uma habilidade que nao sai e um botao quebrado, a menos que o jogador VEJA
## por que ela nao saiu. A capa e uma sombra que desce do topo do botao ao ritmo
## do relogio, com os segundos que faltam no meio — o mesmo desenho que a quarta
## habilidade, a do Eco, ja usava; nada de vocabulario novo na tela.
##
## Nao mexe em `disabled` nem em `modulate` de proposito: quem manda nesses dois
## e o desbloqueio da habilidade, e duas mãos no mesmo estado acabam brigando —
## a espera apagaria um botao que o talento tinha acabado de acender.
var _capas_de_recarga := {}

func _criar_capa_de_recarga(botao: Control, indice: int) -> void:
    if botao == null:
        return
    var capa := Control.new()
    capa.name = "CapaDeRecarga"
    capa.set_anchors_preset(Control.PRESET_FULL_RECT)
    capa.mouse_filter = Control.MOUSE_FILTER_IGNORE
    capa.visible = false
    botao.add_child(capa)

    var sombra := ColorRect.new()
    sombra.color = Color(0.02, 0.03, 0.07, 0.72)
    sombra.set_anchors_preset(Control.PRESET_FULL_RECT)
    sombra.mouse_filter = Control.MOUSE_FILTER_IGNORE
    capa.add_child(sombra)

    var numero := Label.new()
    numero.set_anchors_preset(Control.PRESET_FULL_RECT)
    numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    numero.add_theme_font_size_override("font_size", 24)
    numero.add_theme_color_override("font_color", Color(0.98, 0.92, 0.78))
    numero.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.92))
    numero.add_theme_constant_override("outline_size", 6)
    numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
    capa.add_child(numero)

    _capas_de_recarga[indice] = [capa, sombra, numero, 1.0]


func _pintar_recargas() -> void:
    if _player == null or not _player.has_method("recarga_restante"):
        return
    for indice in _capas_de_recarga:
        var pecas: Array = _capas_de_recarga[indice]
        var capa: Control = pecas[0]
        if not is_instance_valid(capa):
            continue
        var falta: float = _player.recarga_restante(int(indice))
        if falta <= 0.0:
            capa.visible = false
            continue
        # O tempo cheio so e perguntado no quadro em que a espera comeca. Ele
        # consulta os atributos, e fazer isso sessenta vezes por segundo, por
        # habilidade, e conta paga por um numero que nao muda no meio da espera.
        if not capa.visible:
            pecas[3] = maxf(_player.recarga_total(int(indice)), 0.001)
        var cheio: float = maxf(float(pecas[3]), falta)
        capa.visible = true
        # A sombra cobre o que FALTA: cheia no instante do uso, vazia quando a
        # habilidade volta. O topo desce; nao ha calculo de tamanho em pixel,
        # so a ancora, entao ela acompanha qualquer tamanho de botao.
        (pecas[1] as ColorRect).anchor_top = clampf(1.0 - falta / cheio, 0.0, 1.0)
        (pecas[2] as Label).text = str(ceili(falta))


func _criar_botao_skill_eco() -> void:
    var grupo := find_child("BotoesCombate", true, false) as Control
    if grupo == null:
        return
    _btn_skill_eco = Button.new()
    _btn_skill_eco.name = "BtnSkillEco"
    _btn_skill_eco.position = Vector2(7, 98)
    _btn_skill_eco.size = Vector2(72, 72)
    _btn_skill_eco.expand_icon = true
    _btn_skill_eco.tooltip_text = "Habilidade do Eco equipado"
    var fundo := StyleBoxFlat.new()
    fundo.bg_color = Color(0.035, 0.10, 0.18, 0.94)
    fundo.border_color = Color(0.30, 0.84, 1.0, 0.95)
    fundo.set_border_width_all(3)
    fundo.set_corner_radius_all(36)
    for estado in ["normal", "hover", "pressed", "focus", "disabled"]:
        _btn_skill_eco.add_theme_stylebox_override(estado, fundo)
    grupo.add_child(_btn_skill_eco)
    _btn_skill_eco.pressed.connect(_usar_skill_eco)
    _rotulo_cooldown_eco = Label.new()
    _rotulo_cooldown_eco.set_anchors_preset(Control.PRESET_FULL_RECT)
    _rotulo_cooldown_eco.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _rotulo_cooldown_eco.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _rotulo_cooldown_eco.add_theme_font_size_override("font_size", 22)
    _rotulo_cooldown_eco.add_theme_color_override("font_color", Color.WHITE)
    _rotulo_cooldown_eco.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
    _rotulo_cooldown_eco.add_theme_constant_override("outline_size", 5)
    _rotulo_cooldown_eco.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _btn_skill_eco.add_child(_rotulo_cooldown_eco)
    _atualizar_botao_skill_eco()


func _atualizar_botao_skill_eco() -> void:
    if _btn_skill_eco == null:
        return
    var progresso := get_node_or_null("/root/Progresso")
    var id := str(progresso.eco_equipado.get("id", "")) if progresso else ""
    _btn_skill_eco.visible = not id.is_empty()
    if id.is_empty():
        return
    var retrato := "res://textures/ui/ecos/%s.png" % id
    _btn_skill_eco.icon = load(retrato) if ResourceLoader.exists(retrato) else null


func _criar_efeito_skill_eco() -> void:
    _efeito_skill_eco = MeshInstance3D.new()
    _efeito_skill_eco.name = "PulsoDoEco"
    var disco := CylinderMesh.new()
    disco.top_radius = 0.7
    disco.bottom_radius = 0.7
    disco.height = 0.035
    disco.radial_segments = 24
    var material := StandardMaterial3D.new()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.albedo_color = Color(0.10, 0.75, 1.0, 0.42)
    material.emission_enabled = true
    material.emission = Color(0.08, 0.58, 1.0)
    material.emission_energy_multiplier = 1.7
    _efeito_skill_eco.mesh = disco
    _efeito_skill_eco.material_override = material
    # Um ponto microscópico por dois quadros força a compilação deste material
    # durante o carregamento, não no primeiro toque da quarta skill.
    _efeito_skill_eco.scale = Vector3.ONE * 0.01
    _efeito_skill_eco.transparency = 0.99
    _efeito_skill_eco.visible = true
    add_child(_efeito_skill_eco)
    _ocultar_preparo_skill_eco()


func _ocultar_preparo_skill_eco() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    if is_instance_valid(_efeito_skill_eco):
        _efeito_skill_eco.visible = false


func _usar_skill_eco() -> void:
    if _cooldown_skill_eco > 0.0 or _eco_companheiro == null or not is_instance_valid(_eco_companheiro):
        return
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null or str(progresso.eco_equipado.get("id", "")).is_empty():
        return
    _cooldown_skill_eco = 10.0
    _btn_skill_eco.disabled = true
    if _eco_companheiro.has_method("play_attack"):
        _eco_companheiro.play_attack()
    _efeito_skill_eco.global_position = _player.global_position + Vector3.UP * 0.08
    _efeito_skill_eco.scale = Vector3.ONE * 0.25
    _efeito_skill_eco.transparency = 0.0
    _efeito_skill_eco.visible = true
    var pulso := create_tween()
    pulso.set_parallel(true)
    pulso.tween_property(_efeito_skill_eco, "scale", Vector3.ONE * 5.0, 0.42)
    pulso.tween_property(_efeito_skill_eco, "transparency", 1.0, 0.42)
    pulso.chain().tween_callback(func(): _efeito_skill_eco.visible = false)
    var dano := float(progresso.estatisticas().get("poder_harmonico", 30)) * 1.35
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if is_instance_valid(bicho) and bicho.global_position.distance_to(_player.global_position) <= 5.0:
            bicho.levar_dano(dano, bicho.global_position - _player.global_position)
    var hud := get_tree().get_first_node_in_group("player_hud")
    if hud and hud.has_method("conceder_escudo"):
        hud.conceder_escudo(55.0 + float(progresso.valor_atributo("ressonancia")) * 5.0)


func _process(delta: float) -> void:
    _pintar_recargas()
    if _cooldown_skill_eco > 0.0:
        _cooldown_skill_eco = maxf(0.0, _cooldown_skill_eco - delta)
        if _rotulo_cooldown_eco:
            _rotulo_cooldown_eco.text = str(ceili(_cooldown_skill_eco)) if _cooldown_skill_eco > 0.0 else ""
        if _cooldown_skill_eco <= 0.0 and _btn_skill_eco:
            _btn_skill_eco.disabled = false
    _ate_buscar_eco -= delta
    if _ate_buscar_eco <= 0.0:
        _ate_buscar_eco = 0.25
        _buscar_eco_para_captura()

    # ONDE ELE ESTAVA EM PAZ. Guardar o ponto so quando nao ha bicho por perto
    # evita renascer dentro da briga que acabou de matar o jogador — que e o
    # jeito mais rapido de transformar uma morte em cinco.
    _ate_marcar_lugar -= delta
    if _ate_marcar_lugar <= 0.0:
        _ate_marcar_lugar = 1.5
        _marcar_lugar_seguro()
    if not _ressonando:
        _progresso_ressonancia = maxf(0.0, _progresso_ressonancia - delta * 0.20)
        return
    if _eco_captura == null or not is_instance_valid(_eco_captura) or _player.global_position.distance_to(_eco_captura.global_position) > 4.8:
        _ressonando = false
        return
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null or progresso.quantidade("ressonador") <= 0:
        _ressonando = false
        return
    # RESSOAR VIROU AFINAR.
    #
    # Antes era segurar o dedo e esperar quatro segundos e meio: nao havia o que
    # acertar, nao havia o que aprender, e capturar o decimo Eco era igual ao
    # primeiro. Agora um ponteiro varre a faixa e a barra so anda depressa
    # enquanto ele esta DENTRO da janela — que estreita conforme a captura
    # avanca, como afinar de verdade fica mais fino perto do ponto. Segurar
    # parado ainda funciona, so que devagar: o jogo pede pericia sem punir quem
    # nao tem.
    var bonus := 1.0 + maxf(0.0, float(progresso.valor_atributo("ressonancia")) - 6.0) * 0.02
    _fase_da_afinacao += delta * VELOCIDADE_DO_PONTEIRO
    var ponteiro: float = sin(_fase_da_afinacao)
    var janela: float = lerpf(0.38, 0.14, _progresso_ressonancia)
    var afinado: bool = absf(ponteiro) <= janela
    if afinado:
        _tempo_afinado += delta
        if not _estava_afinado:
            _tocar_a_nota_do_eco()
    _estava_afinado = afinado
    _tempo_ressoando += delta
    _progresso_ressonancia += delta / 4.5 * bonus * (2.0 if afinado else 0.42)
    _mostrar_estado_ressonancia(ponteiro, janela, afinado)
    if _progresso_ressonancia >= 1.0:
        _concluir_ressonancia()


## A QUEDA.
##
## Ate ontem a vida do heroi nunca baixava, entao nao existia morte — e quando
## eu liguei o dano do bicho, o jogo passou a permitir chegar a zero e seguir
## andando. Aqui a queda finalmente significa alguma coisa, e de proposito nao
## significa MUITO: perde-se um decimo das Claves e volta-se ao ultimo lugar
## calmo, com a vida cheia. Num jogo cuja materia e aprender musica, punir
## forte a tentativa e o caminho errado.
var _ultimo_lugar_seguro := Vector3.ZERO
var _ate_marcar_lugar := 1.5
var _caido := false
var _veu_da_queda: ColorRect = null

func _marcar_lugar_seguro() -> void:
    if _player == null or _caido:
        return
    for b in get_tree().get_nodes_in_group("bicho"):
        if is_instance_valid(b) and b.global_position.distance_to(_player.global_position) < 16.0:
            return
    _ultimo_lugar_seguro = _player.global_position


func _ao_cair() -> void:
    if _caido:
        return
    _caido = true
    if _player:
        _player.set_physics_process(false)
        _player.velocity = Vector3.ZERO
        # Os DOIS herois soltam o golpe. Morrer no meio de um ataque deixava o
        # estado preso e o jogador voltava sem conseguir atacar nem trocar.
        for corpo in [_player.get_node_or_null("Hero"), _player.get_node_or_null("Wins")]:
            if corpo and corpo.has_method("soltar_ataque"):
                corpo.soltar_ataque()

    # CAIR DENTRO DA CAVERNA NAO E CAIR NO MUNDO.
    #
    # O renascer do mundo aberto leva o heroi ao ultimo lugar calmo — que fica
    # fora da caverna, a centenas de metros — e cobra um decimo das Claves. Nos
    # dois pontos ele esta errado aqui: a incursao tem um comeco proprio para
    # onde voltar, e o preco de morrer na DG ja e perder a incursao inteira.
    # Cobrar Claves POR CIMA disso seria punir duas vezes o mesmo erro.
    var caverna := get_node_or_null("DungeonCaverna")
    if caverna and caverna.has_method("esta_dentro") and caverna.esta_dentro():
        _cair_na_caverna(caverna)
        return

    var perdidas := 0
    var progresso := get_node_or_null("/root/Progresso")
    if progresso:
        perdidas = int(progresso.quantidade("claves") * 0.10)
        if perdidas > 0:
            progresso.adicionar_recurso("claves", -perdidas)

    _montar_veu()
    var tw := create_tween()
    tw.tween_property(_veu_da_queda, "modulate:a", 1.0, 0.45)
    tw.tween_callback(func():
        if _player:
            _player.global_position = _ultimo_lugar_seguro + Vector3.UP * 0.6
            _player.velocity = Vector3.ZERO
        var hud := get_tree().get_first_node_in_group("player_hud")
        if hud and hud.has_method("reerguer"):
            hud.reerguer())
    tw.tween_interval(0.9)
    tw.tween_property(_veu_da_queda, "modulate:a", 0.0, 0.6)
    tw.tween_callback(func():
        _caido = false
        if _player:
            _player.set_physics_process(true)
        var casca := get_tree().root.find_child("UiShell", true, false)
        if casca and casca.has_method("avisar") and perdidas > 0:
            casca.avisar("A harmonia se desfez", "Você perdeu %d Claves na queda" % perdidas))


## O veu escurece, a tela do fim da incursao aparece por cima e o mundo espera a
## escolha do jogador. Quem devolve a fisica e o sinal `queda_resolvida`, que a
## caverna dispara depois de repovoar ou de sair.
func _cair_na_caverna(caverna: Node) -> void:
    if caverna.has_signal("queda_resolvida") \
            and not caverna.queda_resolvida.is_connected(_ao_resolver_a_queda):
        caverna.queda_resolvida.connect(_ao_resolver_a_queda)
    _montar_veu()
    var tw := create_tween()
    tw.tween_property(_veu_da_queda, "modulate:a", 1.0, 0.5)
    tw.tween_callback(func():
        if _player:
            _player.velocity = Vector3.ZERO
        caverna.encerrar_por_queda())
    tw.tween_interval(0.2)
    tw.tween_property(_veu_da_queda, "modulate:a", 0.0, 0.5)
    # Invisivel nao basta: um ColorRect com filtro STOP continua comendo o toque
    # e os botoes da tela do fim ficariam mortos por baixo dele.
    tw.tween_callback(func():
        if is_instance_valid(_veu_da_queda):
            _veu_da_queda.mouse_filter = Control.MOUSE_FILTER_IGNORE)


func _ao_resolver_a_queda() -> void:
    _caido = false
    if _player:
        _player.set_physics_process(true)


func _montar_veu() -> void:
    if _veu_da_queda and is_instance_valid(_veu_da_queda):
        _veu_da_queda.modulate.a = 0.0
        _veu_da_queda.mouse_filter = Control.MOUSE_FILTER_STOP
        return
    var camada := CanvasLayer.new()
    camada.layer = 90
    add_child(camada)
    _veu_da_queda = ColorRect.new()
    _veu_da_queda.color = Color(0.02, 0.01, 0.03, 1.0)
    _veu_da_queda.set_anchors_preset(Control.PRESET_FULL_RECT)
    _veu_da_queda.mouse_filter = Control.MOUSE_FILTER_STOP
    _veu_da_queda.modulate.a = 0.0
    camada.add_child(_veu_da_queda)
    var aviso := Label.new()
    aviso.text = "A harmonia se desfez"
    aviso.add_theme_font_override("font", load("res://fontes/Cinzel.ttf"))
    aviso.add_theme_font_size_override("font_size", 34)
    aviso.add_theme_color_override("font_color", Color(0.90, 0.80, 0.62))
    aviso.set_anchors_preset(Control.PRESET_CENTER)
    aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    aviso.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    aviso.offset_left = -300.0
    aviso.offset_right = 300.0
    aviso.offset_top = -30.0
    aviso.offset_bottom = 30.0
    _veu_da_queda.add_child(aviso)


func _buscar_eco_para_captura() -> void:
    var melhor: Node3D = null
    var menor := 4.8
    for candidato in get_tree().get_nodes_in_group("eco_capturavel"):
        if not is_instance_valid(candidato) or not candidato.has_method("esta_disponivel_para_captura") or not candidato.esta_disponivel_para_captura():
            continue
        var distancia := _player.global_position.distance_to(candidato.global_position)
        if distancia < menor:
            menor = distancia
            melhor = candidato
    if melhor != _eco_captura:
        _eco_captura = melhor
        _progresso_ressonancia = 0.0
        _ressonando = false
    if _hud_ressonancia == null:
        # A montagem da cena cede o quadro em varios pontos, entao _process ja
        # roda antes da HUD existir. Sem esta guarda o primeiro segundo de jogo
        # vira uma enxurrada de erro no console.
        return
    if _eco_captura == null:
        _hud_ressonancia.esconder()
    else:
        _mostrar_estado_ressonancia()


## O PONTEIRO E A JANELA. Sao o unico estado novo da ressonancia, e vivem aqui
## para o HUD continuar sendo so desenho.
const VELOCIDADE_DO_PONTEIRO := 3.1
var _fase_da_afinacao := 0.0
var _tempo_afinado := 0.0
var _tempo_ressoando := 0.0
var _estava_afinado := false
var _voz_da_nota: AudioStreamPlayer = null

## Toca a nota do Eco no instante em que o ponteiro entra na janela. E o
## reforco que transforma o minijogo em treino de ouvido: acertar SOA.
func _tocar_a_nota_do_eco() -> void:
    if _eco_captura == null or not is_instance_valid(_eco_captura):
        return
    var caminho := "res://audio/nota_%s.wav" % str(_eco_captura.eco_id).replace("_sustenido", "")
    if not ResourceLoader.exists(caminho):
        return
    if _voz_da_nota == null or not is_instance_valid(_voz_da_nota):
        _voz_da_nota = AudioStreamPlayer.new()
        _voz_da_nota.volume_db = -7.0
        add_child(_voz_da_nota)
    _voz_da_nota.stream = load(caminho)
    # A sustenida sobe meio tom a partir da natural: um semitom e a raiz doze de
    # dois. O jogo nao tem gravacao das cinco cromaticas, e afinar a natural e
    # mais honesto do que tocar a nota errada.
    _voz_da_nota.pitch_scale = 1.0595 if str(_eco_captura.eco_id).ends_with("_sustenido") else 1.0
    _voz_da_nota.play()


func _mostrar_estado_ressonancia(ponteiro := 0.0, janela := 0.3, afinado := false) -> void:
    if _eco_captura == null or not is_instance_valid(_eco_captura):
        return
    var progresso := get_node_or_null("/root/Progresso")
    var nomes := {"do":"Dó", "do_sustenido":"Dó#", "re":"Ré", "re_sustenido":"Ré#",
        "mi":"Mi", "fa":"Fá", "fa_sustenido":"Fá#", "sol":"Sol",
        "sol_sustenido":"Sol#", "la":"Lá", "la_sustenido":"Lá#", "si":"Si"}
    var id := str(_eco_captura.eco_id)
    _hud_ressonancia.mostrar_eco("Eco de " + str(nomes.get(id, id)), _progresso_ressonancia,
        progresso != null and progresso.quantidade("ressonador") > 0,
        ponteiro, janela, afinado)


func _concluir_ressonancia() -> void:
    var eco := _eco_captura
    var id := str(eco.eco_id)
    var progresso := get_node_or_null("/root/Progresso")
    _ressonando = false
    _eco_captura = null
    _progresso_ressonancia = 0.0
    if progresso == null:
        return
    # A QUALIDADE DA AFINACAO PAGA. Quem ficou dentro da janela leva mais
    # fragmento e tem chance bem maior de Alma — que e o que falta para fechar a
    # escala. Ressoar de qualquer jeito continua valendo; ressoar bem vale mais.
    var qualidade: float = 0.0 if _tempo_ressoando <= 0.0 \
        else clampf(_tempo_afinado / _tempo_ressoando, 0.0, 1.0)
    _tempo_afinado = 0.0
    _tempo_ressoando = 0.0
    _estava_afinado = false
    var fragmentos := _sorte_captura.randi_range(2, 4) + int(round(qualidade * 3.0))
    progresso.adicionar_recurso("fragmento_" + id, fragmentos)
    var chance_alma := minf(0.45, 0.08 + float(progresso.valor_atributo("ressonancia")) * 0.003
        + qualidade * 0.22)
    var ganhou_alma := _sorte_captura.randf() < chance_alma
    if ganhou_alma:
        progresso.adicionar_recurso("alma_eco_" + id, 1)
    var diario := get_node_or_null("/root/Diario")
    if diario:
        diario.registrar("capturar_eco", 1, id)
    _hud_ressonancia.recompensa("Afinação %d%%   •   +%d fragmentos%s" % [
        int(qualidade * 100.0), fragmentos, "  •  +1 Alma rara" if ganhou_alma else ""])
    var casca := get_tree().root.find_child("UiShell", true, false)
    if casca and casca.has_method("avisar") and ganhou_alma:
        casca.avisar("Alma capturada", "Alma do Eco de %s" % str(id).replace("_sustenido", "#"))
    eco.play_disappear()
    _reaparecer_eco_depois(eco)


func _reaparecer_eco_depois(eco: Node) -> void:
    await get_tree().create_timer(45.0).timeout
    if is_instance_valid(eco) and eco.has_method("reaparecer"):
        eco.reaparecer()

## Gancho de teste, irmao do que ja existe no game.gd: rodar com `-- --shot`
## salva um quadro em user://shot.png e sai. E assim que se confere a HUD sem
## depender de alguem olhar a tela e descrever.
func _tirar_print() -> void:
    await get_tree().process_frame
    await get_tree().process_frame
    await get_tree().create_timer(1.5).timeout
    # `-- --shot --inv` abre o inventario antes do clique: conferir tela de menu
    # sem isso exigiria alguem segurando o celular.
    # `-- --shot --bicho` planta um Shiker na frente do jogador antes do clique:
    # conferir barra de vida sem isso exige esperar um nascer sozinho.
    # `-- --norte` sobe o mapa de zona em zona, contando o que acontece em cada
    # borda: e a unica forma de conferir portal sem alguem andando ate la.
    if OS.get_cmdline_user_args().has("--dg"):
        var dg := find_child("DungeonCaverna", true, false)
        if dg and dg.has_method("_entrar"):
            dg._entrar()
            await get_tree().create_timer(1.0).timeout
    # `-- --parede` percorre a DG de ponta a ponta e diz ATE ONDE deu para ir.
    # O teste antigo media "parou na parede" e chamava isso de sucesso — sem
    # perceber que parar era o problema, porque a sala estava lacrada.
    # `-- --gta` liga a camera de ombro e o medidor para a captura de conferencia.
    if OS.get_cmdline_user_args().has("--gta"):
        var aj := find_child("Ajustes", true, false)
        if aj:
            aj.call("_escolher_camera", true)
            if not bool(aj.get("_medidor_ligado")):
                aj.call("_alternar_medidor")
        await get_tree().create_timer(0.8).timeout

    # `-- --giro` segura o analogico DE LADO com a camera de ombro ligada e le o
    # giro dela quadro a quadro. E o teste do ciclo de realimentacao: se o giro
    # crescer sem parar, a camera esta se perseguindo de novo.
    if OS.get_cmdline_user_args().has("--giro"):
        var aj2 := find_child("Ajustes", true, false)
        if aj2:
            aj2.call("_escolher_camera", true)
        await get_tree().create_timer(0.5).timeout
        var cam := find_child("IsometricCamera", true, false)
        if cam == null:
            for n in get_tree().root.find_children("*", "Node3D", true, false):
                if n.get_script() and str(n.get_script().resource_path).ends_with("isometric_camera.gd"):
                    cam = n
                    break
        Input.action_press("ui_right")
        for i in 5:
            await get_tree().create_timer(0.5).timeout
            print("GIRO andando %.1fs: camera %+.1f graus | heroi %+.1f graus" % [
                (i + 1) * 0.5, rad_to_deg(cam.rotation.y), rad_to_deg(_player.rotation.y)])
        Input.action_release("ui_right")
        for i in 4:
            await get_tree().create_timer(0.6).timeout
            print("GIRO parado  %.1fs: camera %+.1f graus | heroi %+.1f graus" % [
                (i + 1) * 0.6, rad_to_deg(cam.rotation.y), rad_to_deg(_player.rotation.y)])

    # `-- --mundo` desenha a grade que saiu das saidas e ATRAVESSA uma divisa a
    # pe, medindo o chao a cada passo. Degrau na costura e queda no vazio sao os
    # dois jeitos de o mundo continuo falhar, e ambos aparecem no numero.
    # `-- --vila` poe o heroi no centro da Vila do Caminho e espera a regiao
    # montar. Conferir rua, casa e minimapa la exigia caminhar 160 m.
    if OS.get_cmdline_user_args().has("--vila"):
        var zbv := find_child("ZoneBuilder", true, false)
        var onde: Vector3 = zbv.deslocamento_da_celula(
            zbv._celulas.get("zone_vila_caminho", Vector2i.ZERO))
        _player.global_position = onde + Vector3(6.0, 2.0, 26.0)
        await get_tree().create_timer(3.0).timeout

    # Gancho genérico para conferir qualquer ponto do novo mapa regional:
    # `--zona=zone_portoes --local=48,0`.
    for argumento in OS.get_cmdline_user_args():
        if not argumento.begins_with("--zona="):
            continue
        var zid := argumento.trim_prefix("--zona=")
        var zb_regiao := find_child("ZoneBuilder", true, false)
        if zb_regiao == null or not zb_regiao._celulas.has(zid):
            continue
        var zm_regiao := find_child("ZoneManager", true, false)
        if zm_regiao:
            await zm_regiao.carregar_zona(zid, "center")
        var local := Vector2.ZERO
        for local_arg in OS.get_cmdline_user_args():
            if local_arg.begins_with("--local="):
                var partes := local_arg.trim_prefix("--local=").split(",")
                if partes.size() >= 2:
                    local = Vector2(float(partes[0]), float(partes[1]))
        var ponto: Vector3 = zb_regiao.deslocamento_da_celula(zb_regiao._celulas[zid]) + Vector3(local.x, 0.0, local.y)
        ponto.y = zb_regiao.calcular_altura(ponto.x, ponto.z) + 1.2
        _player.global_position = ponto
        var rig_regiao := find_child("CameraRig", true, false) as Node3D
        if rig_regiao:
            rig_regiao.global_position = ponto
        await get_tree().create_timer(5.0).timeout

    if OS.get_cmdline_user_args().has("--mundo"):
        var zb := find_child("ZoneBuilder", true, false)
        print("MUNDO grade:")
        for zid in zb._celulas.keys():
            print("   %s em %s" % [zid, zb._celulas[zid]])
        var passo := 0.0
        while passo <= 220.0:
            var z := 80.0 - passo
            _player.global_position = Vector3(0.0, zb.calcular_altura(0.0, z) + 1.0, z)
            await get_tree().physics_frame
            await get_tree().physics_frame
            if int(passo) % 20 == 0:
                print("MUNDO z=%+7.1f | zona %-24s | chao %+6.2f | heroi %+6.2f | regioes %d" % [
                    z, zb.zona_no_ponto(0.0, z), zb.calcular_altura(0.0, z),
                    _player.global_position.y, zb._regioes.size()])
            passo += 5.0

    if OS.get_cmdline_user_args().has("--dg2"):
        await get_tree().create_timer(1.0).timeout
        for n in get_tree().root.find_children("*", "Node3D", true, false):
            if n.get_script() and str(n.get_script().resource_path).ends_with("dungeon_caverna.gd"):
                n.call("_entrar")
                break
        await get_tree().create_timer(0.8).timeout

    if OS.get_cmdline_user_args().has("--parede"):
        await get_tree().create_timer(1.2).timeout
        var dg: Node = null
        for n in get_tree().root.find_children("*", "Node3D", true, false):
            if n.get_script() and str(n.get_script().resource_path).ends_with("dungeon_caverna.gd"):
                dg = n
                break
        if dg == null:
            print("TESTE: nao achei o no da DG")
        else:
            dg.call("_entrar")
            await get_tree().create_timer(0.6).timeout
            var origem := Vector3(520, 0, 520)
            # Caminha do sul para o norte pelo eixo principal, empurrando de
            # leve para os lados quando trava — como um jogador faria.
            _player.global_position = origem + Vector3(0, 1.2, 78)
            _player.velocity = Vector3.ZERO
            for i in 6: await get_tree().physics_frame
            var mais_ao_norte: float = 78.0
            for i in 1200:
                await get_tree().physics_frame
                var lado: float = sin(float(i) * 0.08) * 2.5
                _player.velocity = Vector3(lado, -2.0, -6.0)
                _player.move_and_slide()
                var z_local: float = _player.global_position.z - origem.z
                mais_ao_norte = minf(mais_ao_norte, z_local)
            print("TESTE: partiu de z=78 e chegou a z=%.1f (arena fica em -60, estagio 2 em -180)" % mais_ao_norte)

    if OS.get_cmdline_user_args().has("--norte"):
        var zm := find_child("ZoneManager", true, false)
        var total_de_saltos := 1 if OS.get_cmdline_user_args().has("--vila") else 2
        for salto in total_de_saltos:
            await get_tree().create_timer(1.2).timeout
            var construtor := find_child("ZoneBuilder", true, false)
            var alvo := Vector3(0.0, 2.0, -68.0)
            if construtor and construtor.has_method("calcular_altura"):
                alvo.y = construtor.calcular_altura(alvo.x, alvo.z) + 1.5
            _player.global_position = alvo
            var portais := get_tree().root.find_children("Portal_*", "", true, false)
            var estado := []
            for pt in portais:
                estado.append("%s(ativo=%s, z=%.0f, dest=%s)" % [pt.name, str(pt._active), pt.global_position.z, pt.dest_zone_id])
            print("TESTE salto %d: saindo de %s em %s | portais: %s" % [salto,
                zm._current_zone_id if zm else "?", str(alvo), ", ".join(estado)])
            for i in 90:
                await get_tree().physics_frame
                _player.global_position.z -= 0.1
            print("TESTE salto %d: chegou em %s, heroi em %s" % [salto,
                zm._current_zone_id if zm else "?", str(_player.global_position)])
        if OS.get_cmdline_user_args().has("--centro"):
            var centro := Vector3.ZERO
            var construtor_centro := find_child("ZoneBuilder", true, false)
            if construtor_centro and construtor_centro.has_method("calcular_altura"):
                centro.y = construtor_centro.calcular_altura(0.0, 0.0) + 1.5
            _player.global_position = centro
            var camera_rig := find_child("CameraRig", true, false) as Node3D
            if camera_rig:
                camera_rig.global_position = centro
            await get_tree().create_timer(0.8).timeout

    if OS.get_cmdline_user_args().has("--bicho"):
        var Bicho := load("res://scripts/bicho.gd")
        for i in 2:
            var b: Node3D = Bicho.new()
            b.monster_type = i * 2
            add_child(b)
            b.global_position = _player.global_position + Vector3(2.5 - 5.0 * i, 0.5, -4.0)
            await get_tree().process_frame
            b.levar_dano(b.vida_maxima * 0.45, Vector3.FORWARD)
        await get_tree().create_timer(0.5).timeout
    if OS.get_cmdline_user_args().has("--ajustes"):
        var aj := find_child("Ajustes", true, false)
        if aj:
            aj.mostrar(true)
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--ficha"):
        var f := _shell
        if f:
            f.mostrar(true)
            for argumento in OS.get_cmdline_user_args():
                if argumento.begins_with("--aba=") and f.has_method("_mudar_aba_v3"):
                    f._mudar_aba_v3(argumento.trim_prefix("--aba="))
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--sintese"):
        var s := _shell
        if s:
            s.mostrar(true)
            if OS.get_cmdline_user_args().has("--partituras"):
                s._trocar_aba("partituras")
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--skills"):
        _abrir_tela_skills()
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--ecos"):
        _abrir_tela_ecos()
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--fala"):
        if _dialogo:
            _dialogo.comecar("renaldo_portao" if OS.get_cmdline_user_args().has("--renaldo") else "mirella_boas_vindas")
        await get_tree().create_timer(0.4).timeout
    if OS.get_cmdline_user_args().has("--inv"):
        _shell.abrir("inventario")
        await get_tree().create_timer(0.4).timeout
    # QA visual responsivo: `-- --shot --ui=personagem` abre qualquer pagina
    # do shell oficial antes da captura. Mantem a verificacao no proprio jogo,
    # em vez de depender de um prototipo separado.
    for argumento in OS.get_cmdline_user_args():
        if argumento.begins_with("--ui="):
            var pagina_ui := argumento.trim_prefix("--ui=")
            if _shell:
                _shell.abrir(pagina_ui)
                await get_tree().create_timer(0.7).timeout
    if OS.get_cmdline_user_args().has("--galeria-ui") and DisplayServer.get_name() != "headless":
        for pagina_ui in ["personagem", "inventario", "sintese", "forja_escalas"]:
            _shell.abrir(pagina_ui)
            await get_tree().create_timer(0.8).timeout
            var captura_ui := get_viewport().get_texture().get_image()
            if captura_ui:
                captura_ui.save_png("user://ui-mobile-%s.png" % pagina_ui)
                print("SHOT UI ", pagina_ui, " ", ProjectSettings.globalize_path(
                    "user://ui-mobile-%s.png" % pagina_ui))
        get_tree().quit()
        return
    if OS.get_cmdline_user_args().has("--mapa"):
        _shell.abrir("mapa")
        await get_tree().create_timer(0.5).timeout
    if DisplayServer.get_name() == "headless":
        print("SHOT indisponível no renderizador headless; árvore validada.")
        get_tree().quit()
        return
    var imagem := get_viewport().get_texture().get_image()
    if imagem:
        imagem.save_png("user://shot.png")
        print("SHOT ", ProjectSettings.globalize_path("user://shot.png"))
    else:
        # O renderizador dummy do teste headless não possui textura. Ainda
        # assim o teste deve encerrar, em vez de deixar um Godot preso por horas.
        print("SHOT indisponível no renderizador headless; árvore validada.")
    get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_1:
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(1)
                get_viewport().set_input_as_handled()
        elif event.keycode == KEY_2:
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(2)
                get_viewport().set_input_as_handled()
        elif event.keycode == KEY_3:
            if _player and _player.has_method("usar_skill"):
                _player.usar_skill(3)
                get_viewport().set_input_as_handled()
        elif event.keycode == KEY_SPACE:
            if _player and _player.has_method("atacar"):
                _player.atacar()
                get_viewport().set_input_as_handled()


# -------------------------------------------------------------
# Conversa: quem esta perto, e o botao que troca de cara
# -------------------------------------------------------------
## Ligado pelo ZoneManager quando a zona termina de nascer, e a cada troca de
## zona: os NPCs sao criados junto com o cenario, entao nao da para conectar
## uma vez no _ready e esquecer.
func registrar_npcs() -> void:
    _npc_perto = null
    for npc in get_tree().get_nodes_in_group("npc"):
        if not npc.jogador_chegou.is_connected(_ao_chegar_perto):
            npc.jogador_chegou.connect(_ao_chegar_perto)
            npc.jogador_saiu.connect(_ao_afastar)
    _pintar_botao()


## UMA BOCA DE CAVERNA EM CADA TERRA SELVAGEM.
##
## So onde o chao e natural: as zonas com planta urbana (`layout_id`) tem casa,
## praca e calcada desenhadas a mao, e um arco de pedra de seis metros plantado
## por codigo no meio disso nasceria dentro de uma parede. Sobram os campos, as
## florestas e a serra — que e onde uma caverna faz sentido de qualquer forma.
##
## E a MESMA caverna vista por bocas diferentes, e o rotulo diz isso: nao ha
## cinco masmorras, ha cinco entradas.
const RAIO_DO_PORTAL := 42.0

func _semear_portais() -> void:
    var arquivo := FileAccess.open("res://data/acordelot_regiao_1.json", FileAccess.READ)
    if arquivo == null:
        arquivo = FileAccess.open("res://data/zones_db.json", FileAccess.READ)
    if arquivo == null:
        return
    var banco = JSON.parse_string(arquivo.get_as_text())
    if not (banco is Dictionary):
        return
    var zonas: Dictionary = banco.get("zones", {})
    for zid in zonas:
        var z: Dictionary = zonas[zid]
        if str(z.get("layout_id", "")) != "":
            continue
        var grade: Array = z.get("grid_pos", [])
        if grade.size() < 2:
            continue
        var centro := Vector3(float(grade[0]) * 160.0, 0.0, float(grade[1]) * 160.0)
        var onde := _lugar_para_o_portal(centro, str(zid).hash())
        var portal: Area3D = PortalCavernaScript.new()
        portal.name = "PortalCaverna_" + str(zid)
        portal.subtitulo = str(z.get("name", ""))
        add_child(portal)
        portal.global_position = onde
        # De frente para o miolo da zona: quem anda pelo meio do mapa ve o vao,
        # e nao as costas do arco.
        var para_o_centro := centro - onde
        portal.rotation.y = atan2(para_o_centro.x, para_o_centro.z)
        portal.jogador_chegou.connect(_ao_chegar_no_portal)
        portal.jogador_saiu.connect(_ao_sair_do_portal)


## Escolhe, entre doze pontos no anel em volta do centro da zona, o mais PLANO.
## Um arco de seis metros numa ladeira fica com metade enterrada e a outra
## metade no ar, e nao ha como consertar isso depois de plantado.
func _lugar_para_o_portal(centro: Vector3, semente: int) -> Vector3:
    var melhor := centro
    var menor_desnivel := INF
    for i in 12:
        var angulo: float = TAU * (float(i) / 12.0 + float(semente % 97) / 97.0)
        var p := centro + Vector3(cos(angulo), 0.0, sin(angulo)) * RAIO_DO_PORTAL
        var h := Relevo.altura(p.x, p.z)
        var desnivel := 0.0
        for canto in [Vector2(3.0, 0.0), Vector2(-3.0, 0.0),
                Vector2(0.0, 3.0), Vector2(0.0, -3.0)]:
            desnivel = maxf(desnivel,
                absf(Relevo.altura(p.x + canto.x, p.z + canto.y) - h))
        if desnivel < menor_desnivel:
            menor_desnivel = desnivel
            melhor = Vector3(p.x, h, p.z)
    return melhor


func _ao_chegar_no_portal(portal: Node) -> void:
    _portal_perto = portal
    _pintar_botao()


func _ao_sair_do_portal(portal: Node) -> void:
    if _portal_perto == portal:
        _portal_perto = null
    _pintar_botao()


## O Cavaleiro e um chefe de regiao, nao uma sala da DG. Ele guarda uma
## clareira da Floresta dos Ecos e fica dormente ate o desafio ser aceito.
func _semear_cavaleiro_regional() -> void:
    if get_node_or_null("CavaleiroRegional"):
        return
    var encontro := ChefeRegionalScript.new()
    encontro.name = "CavaleiroRegional"
    add_child(encontro)
    # O CHAO DA ARENA TEM DE SER PLANO.
    #
    # Ele estava em (116, 56), no canto da Floresta dos Ecos, com 3,90 m de
    # desnivel dentro do circulo de catorze metros — ladeira. Um chefe de tres
    # metros e meio brigando numa rampa fica meio enterrado de um lado e no ar
    # do outro, e a camera isometrica perde ele atras do barranco.
    #
    # Medido em vinte e cinco pontos da zona, o melhor e (138, 0): 1,78 m de
    # desnivel, no eixo do meio da regiao e longe das bordas.
    var p := Vector3(138.0, 0.0, 0.0)
    # Se uma boca de caverna tiver caido perto, ele anda para o lado: duas coisas
    # que pedem o mesmo toque de acao a poucos metros uma da outra viram briga
    # pelo botao.
    for portal in get_tree().get_nodes_in_group("portal_dungeon"):
        if p.distance_to(Vector3(portal.global_position.x, 0.0, portal.global_position.z)) < 34.0:
            p += Vector3(26.0, 0.0, -18.0)
            break
    encontro.global_position = Vector3(p.x, Relevo.altura(p.x, p.z) + 0.15, p.z)
    encontro.jogador_chegou.connect(func(qual):
        _chefe_perto = qual
        _pintar_botao())
    encontro.jogador_saiu.connect(func(qual):
        if _chefe_perto == qual: _chefe_perto = null
        _pintar_botao())


func _entrar_pelo_portal() -> void:
    var caverna := get_node_or_null("DungeonCaverna")
    if caverna and caverna.has_method("abrir_tela_de_entrada"):
        caverna.abrir_tela_de_entrada()


func _ao_chegar_perto(npc: Node) -> void:
    _npc_perto = npc
    if npc.has_method("olhar_para") and _player:
        npc.olhar_para(_player.global_position)
    _pintar_botao()


func _ao_afastar(npc: Node) -> void:
    if _npc_perto == npc:
        _npc_perto = null
    _pintar_botao()


func _conversar() -> void:
    if _npc_perto == null or _dialogo == null or _dialogo.esta_ativo():
        return
    if not _dialogo.comecar(str(_npc_perto.dialogo)):
        return
    if _npc_perto.has_method("parar_para_conversar"):
        _npc_perto.parar_para_conversar()
    # O heroi para enquanto conversa. Andar com a caixa aberta faria a NPC
    # ficar para tras falando sozinha.
    if _player:
        _player.set_physics_process(false)
    _pintar_botao()


## O botao de ataque vira botao de conversa e volta.
##
## Nao ha arte propria para "conversar": a mesma moldura entra esverdeada e com
## a legenda embaixo, que e o suficiente para o jogador entender que aquele
## toque mudou de assunto — e nao custa uma textura nova na build.
func _pintar_botao() -> void:
    if _btn_ataque == null:
        return
    var conversando: bool = _npc_perto != null and (_dialogo == null or not _dialogo.esta_ativo())
    var desafiando: bool = not conversando and _chefe_perto != null
    var na_boca: bool = not conversando and not desafiando and _portal_perto != null
    if conversando:
        _btn_ataque.modulate = Color(0.62, 1.0, 0.72)
    elif na_boca:
        _btn_ataque.modulate = Color(0.82, 0.62, 1.0)
    elif desafiando:
        _btn_ataque.modulate = Color(1.0, 0.72, 0.32)
    else:
        _btn_ataque.modulate = Color.WHITE

    var legenda := _btn_ataque.get_node_or_null("Legenda") as Label
    if legenda == null:
        legenda = Label.new()
        legenda.name = "Legenda"
        legenda.add_theme_font_size_override("font_size", 13)
        legenda.add_theme_color_override("font_color", Color(0.95, 0.99, 0.9))
        legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        legenda.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
        legenda.offset_top = -18.0
        legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _btn_ataque.add_child(legenda)
    legenda.text = "Conversar" if conversando else ("Aceitar desafio" if desafiando else ("Entrar na caverna" if na_boca else ""))
