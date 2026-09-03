extends CharacterBody3D
class_name Bicho

signal derrotado(inimigo: Node)

## Inimigos de Acordelot 2.0: Shikers e Golems da Caverna.
const CENA_SHIKER := preload("res://personagem/shiker_base.fbx")
const BIBLIOTECA_SHIKER := preload("res://personagem/shiker_anims.res")
const PELE_SHIKER := preload("res://personagem/shiker_cor.png")

const CENA_GOLEM := preload("res://personagem/golem_base.fbx")
const BIBLIOTECA_GOLEM := preload("res://personagem/golem_anims.res")
const PELE_GOLEM := preload("res://personagem/golem_cor.png")
const CENA_CAVALEIRO := "res://scenes/cavaleiro_chefe.tscn"
const ProjetilCavaleiroScript := preload("res://scripts/projetil_cavaleiro.gd")

const BRILHO := preload("res://textures/brilho_poste.png")

const MONSTROS_CONFIG := [
    # 0, 1, 2: Família Shiker
    {"nome": "Shiker", "cena": CENA_SHIKER, "biblioteca": BIBLIOTECA_SHIKER, "pele": PELE_SHIKER, "prefixo": "shiker",
     "altura": 1.9, "hp": 140.0, "dano": 14.0, "aura": Color(0, 0, 0, 0), "velocidade": 3.0},
    {"nome": "Shiker Voraz", "cena": CENA_SHIKER, "biblioteca": BIBLIOTECA_SHIKER, "pele": PELE_SHIKER, "prefixo": "shiker",
     "altura": 2.3, "hp": 280.0, "dano": 24.0, "aura": Color(0.95, 0.45, 0.12), "velocidade": 3.4},
    {"nome": "Shiker Ancião", "cena": CENA_SHIKER, "biblioteca": BIBLIOTECA_SHIKER, "pele": PELE_SHIKER, "prefixo": "shiker",
     "altura": 2.9, "hp": 550.0, "dano": 40.0, "aura": Color(0.75, 0.32, 0.98), "velocidade": 3.8},
    
    # 3, 4, 5: Família Golem da Caverna (Novo Monstro)
    {"nome": "Golem de Pedra", "cena": CENA_GOLEM, "biblioteca": BIBLIOTECA_GOLEM, "pele": PELE_GOLEM, "prefixo": "golem",
     "altura": 2.2, "hp": 380.0, "dano": 28.0, "aura": Color(0.85, 0.55, 0.2), "velocidade": 2.6},
    {"nome": "Golem Cristalino", "cena": CENA_GOLEM, "biblioteca": BIBLIOTECA_GOLEM, "pele": PELE_GOLEM, "prefixo": "golem",
     "altura": 2.6, "hp": 720.0, "dano": 46.0, "aura": Color(0.45, 0.70, 1.0), "velocidade": 3.0},
    {"nome": "Colosso Ancestral", "cena": CENA_GOLEM, "biblioteca": BIBLIOTECA_GOLEM, "pele": PELE_GOLEM, "prefixo": "golem",
     "altura": 3.3, "hp": 1800.0, "dano": 65.0, "aura": Color(1.0, 0.85, 0.35), "velocidade": 3.4},
    # 6: chefe cavaleiro. O wrapper preserva as tres texturas do GLB e cria as
    # animacoes diretamente no rig Tripo.
    {"nome": "Cavaleiro da Nota Silenciada", "cena": CENA_CAVALEIRO,
     "biblioteca": null, "pele": null, "prefixo": "cavaleiro",
     "altura": 3.40, "hp": 2400.0, "dano": 72.0,
     "aura": Color(0.52, 0.34, 1.0), "velocidade": 3.7,
     "preservar_materiais": true},
]

@export var monster_type: int = 0

var vida_maxima: float = 200.0
var vida: float = 200.0

const VELOCIDADE := 3.2
const RAIO_DE_ATENCAO := 13.5
## Quanto o bicho enxerga. Vale o padrao no mundo aberto; a DG sobe este valor,
## porque corredor fechado com o mesmo raio do campo aberto faz o jogador ter de
## encostar no monstro para ele reagir.
@export var raio_de_atencao := RAIO_DE_ATENCAO
const DISTANCIA_DE_PARADA := 2.2
const GRAVIDADE := 24.0
const ATORDOAMENTO := 0.35
const EMPURRAO := 6.5

var _modelo: Node3D
var _materials: Array[StandardMaterial3D] = []
var _atordoado_ate := -1.0
var _fase := 0.0
var _jogador: Node3D
var _hp_label_3d: Label3D
var _name_label_3d: Label3D
var _anim_player: AnimationPlayer
var _animacao_atual := ""
var _prefixo_anim := "shiker"
var _aura: MeshInstance3D = null
var _fagulhas: CPUParticles3D = null
var _centro_do_corpo := Vector3.ZERO
var _barra_fundo: MeshInstance3D = null
var _velocidade := VELOCIDADE
var _morrendo := false
var _colado_no_jogador := false
var _atordoamento_maximo := ATORDOAMENTO
var _ataque_ate := -1.0
var _nome_personalizado := ""
var _forma_do_cavaleiro := 1
var _invulneravel_ate := -1.0
var _apresentou_cavaleiro := false
## Chefes regionais entregam o espolio pela tela de conclusao. Isto impede que
## o drop comum e o premio da batalha paguem a mesma morte duas vezes.
var recompensa_controlada_externamente := false

## RONDA ANTES DA BRIGA.
##
## Um chefe de regiao parado feito estatua ate alguem falar com ele nao parece
## que mora ali — parece cenario. Em ronda ele anda um circuito curto em volta
## do proprio posto, sem perseguir, sem golpear e sem levar dano. E so quando o
## desafio comeca que ele vira inimigo.
var em_ronda := false
var posto_da_ronda := Vector3.ZERO
var raio_da_ronda := 9.0
var _fase_da_ronda := 0.0
var _fala_ate := -1.0

static var _estoque: Array = []

static func encher_estoque(_quantos: int = 4) -> void:
    pass

func _ready() -> void:
    add_to_group("bicho")
    _fase = randf() * TAU
    
    var cfg: Dictionary = MONSTROS_CONFIG[monster_type % MONSTROS_CONFIG.size()]
    _prefixo_anim = str(cfg.get("prefixo", "shiker"))
    vida_maxima = float(cfg.get("hp", 200.0))
    _dano_do_corpo = float(cfg.get("dano", 14.0))
    vida = vida_maxima
    _velocidade = float(cfg.get("velocidade", VELOCIDADE))
    
    var forma := CollisionShape3D.new()
    var capsula := CapsuleShape3D.new()
    capsula.radius = 0.8
    capsula.height = float(cfg.get("altura", 2.2))
    forma.shape = capsula
    forma.position.y = capsula.height * 0.5
    add_child(forma)
    
    _construir_modelo(cfg)
    _construir_barra_vida_3d(cfg)


func _construir_modelo(cfg: Dictionary) -> void:
    # O chefe regional pesa muito mais que um Shiker. O caminho dele permanece
    # como String na tabela e so e carregado quando o encontro realmente nasce;
    # abrir o jogo no centro de Acordelot nao paga esse custo.
    var recurso = cfg.get("cena", CENA_SHIKER)
    var cena_modelo: PackedScene = load(String(recurso)) if recurso is String else recurso
    _modelo = cena_modelo.instantiate()
    add_child(_modelo)
    _vestir(cfg)
    _preparar_animacoes(cfg)
    _assentar(cfg)
    _acender_aura(cfg)


func _assentar(cfg: Dictionary) -> void:
    var caixa := AABB()
    var achou := false
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        var local: AABB = _ate_a_raiz(malha as Node3D, _modelo) * (malha as MeshInstance3D).get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    if not achou or caixa.size.y <= 0.05:
        return
    var fator: float = clampf(float(cfg.get("altura", 2.0)) / caixa.size.y, 0.05, 6.0)
    _modelo.scale = Vector3.ONE * fator
    _modelo.position.y = -caixa.position.y * fator

    _centro_do_corpo = Vector3(
        (caixa.position.x + caixa.size.x * 0.5) * fator, 0.0,
        (caixa.position.z + caixa.size.z * 0.5) * fator)


func _ate_a_raiz(no: Node3D, raiz: Node3D) -> Transform3D:
    var t := Transform3D.IDENTITY
    var atual: Node = no
    while atual and atual != raiz:
        if atual is Node3D:
            t = (atual as Node3D).transform * t
        atual = atual.get_parent()
    return t


func _vestir(cfg: Dictionary) -> void:
    if bool(cfg.get("preservar_materiais", false)):
        return
    var tex: Texture2D = cfg.get("pele", PELE_SHIKER)
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = tex
    mat.metallic = 0.0
    mat.roughness = 0.88
    
    # A COR DO TIER NAO PINTA A CRIATURA.
    #
    # A emissao ficava na PELE: o Shiker Ancião era um bicho roxo brilhante, e o
    # que devia dizer "este e mais forte" acabava dizendo "este e de outra
    # especie". A marca do tier e o que fica EM VOLTA — as fagulhas e o halo no
    # chao. A pele continua sendo a pele.
    var cor_aura: Color = cfg.get("aura", Color(0, 0, 0, 0))

    _materials = [mat]
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        (malha as MeshInstance3D).material_override = mat


func _preparar_animacoes(cfg: Dictionary) -> void:
    _anim_player = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if _anim_player == null:
        return
    var bib: AnimationLibrary = cfg.get("biblioteca", BIBLIOTECA_SHIKER)
    if bib:
        _anim_player.add_animation_library(_prefixo_anim, bib)
        _tocar("parado", 0.0)
    elif not _anim_player.get_animation_list().is_empty():
        _anim_player.play(_anim_player.get_animation_list()[0])


func _tocar(nome: String, mistura := 0.2) -> void:
    if _anim_player == null or _animacao_atual == nome:
        return
    
    var chave := _prefixo_anim + "/" + nome
    if not _anim_player.has_animation(chave):
        # Fallbacks inteligentes entre kits de animacao
        if nome == "correr":
            chave = _prefixo_anim + "/andar"
        elif nome == "morrer":
            chave = _prefixo_anim + "/morte"
        elif nome == "morte":
            chave = _prefixo_anim + "/morrer"
        elif nome == "atacar":
            chave = _prefixo_anim + "/ataque_1"
        elif nome == "ataque_1" or nome == "ataque_2":
            chave = _prefixo_anim + "/atacar"
    
    if _anim_player.has_animation(chave):
        _animacao_atual = nome
        _anim_player.play(chave, mistura)


func _acender_aura(cfg: Dictionary) -> void:
    var cor: Color = cfg.get("aura", Color(0, 0, 0, 0))
    if cor.a <= 0.01:
        return

    var quadro := QuadMesh.new()
    quadro.size = Vector2(2.8, 2.8) * (1.0 + 0.25 * float(monster_type))
    quadro.orientation = PlaneMesh.FACE_Y
    quadro.center_offset = Vector3(0.0, 0.06, 0.0)

    var material := StandardMaterial3D.new()
    material.albedo_texture = BRILHO
    material.albedo_color = cor
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    quadro.material = material

    _aura = MeshInstance3D.new()
    _aura.name = "Aura"
    _aura.position = _centro_do_corpo
    _aura.mesh = quadro
    _aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_aura)

    var fagulhas := CPUParticles3D.new()
    fagulhas.amount = 18
    fagulhas.lifetime = 1.3
    fagulhas.mesh = QuadMesh.new()
    (fagulhas.mesh as QuadMesh).size = Vector2(0.18, 0.18)
    var mat_fagulha := StandardMaterial3D.new()
    mat_fagulha.albedo_texture = BRILHO
    mat_fagulha.albedo_color = cor
    mat_fagulha.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    mat_fagulha.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat_fagulha.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_fagulha.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    (fagulhas.mesh as QuadMesh).material = mat_fagulha
    # AS FAGULHAS SOBEM EM VOLTA, NAO DE DENTRO.
    #
    # A emissao era uma ESFERA CHEIA de raio 1,1 no meio do peito: metade das
    # particulas nascia dentro da malha e aparecia grudada na pele, como se a
    # criatura estivesse manchada de laranja. Um anel em volta do corpo, com
    # miolo vazado, faz a mesma luz virar contorno — que e o que marca o tier.
    var largura: float = maxf(float(cfg.get("altura", 2.0)) * 0.40, 0.75)
    fagulhas.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
    fagulhas.emission_ring_axis = Vector3.UP
    fagulhas.emission_ring_radius = largura + 0.22
    fagulhas.emission_ring_inner_radius = largura
    fagulhas.emission_ring_height = float(cfg.get("altura", 2.0)) * 0.85
    fagulhas.amount = 26
    fagulhas.direction = Vector3.UP
    fagulhas.spread = 8.0
    fagulhas.initial_velocity_min = 0.15
    fagulhas.initial_velocity_max = 0.55
    fagulhas.gravity = Vector3(0.0, 1.1, 0.0)
    fagulhas.scale_amount_min = 0.6
    fagulhas.scale_amount_max = 1.0
    fagulhas.position = _centro_do_corpo + Vector3.UP * (float(cfg.get("altura", 2.0)) * 0.45)
    add_child(fagulhas)
    _fagulhas = fagulhas


const PAUSA_DO_GOLPE := 1.1

func _golpear() -> void:
    if _anim_player == null:
        _tocar("parado")
        return
    
    var anim_golpe := "atacar"
    if _prefixo_anim == "golem":
        anim_golpe = "ataque_1" if randf() > 0.45 else "ataque_2"
    
    var chave := _prefixo_anim + "/" + anim_golpe
    if not _anim_player.has_animation(chave):
        chave = _prefixo_anim + "/ataque_1"
    
    if _anim_player.has_animation(chave):
        _animacao_atual = anim_golpe
        _anim_player.play(chave, 0.15)
        var duracao: float = _anim_player.get_animation(chave).length
        _ataque_ate = Time.get_ticks_msec() / 1000.0 + duracao + PAUSA_DO_GOLPE
        _marcar_impacto(duracao * FRACAO_DO_IMPACTO)


## O GOLPE CORPO A CORPO NAO MACHUCAVA NINGUEM.
##
## `_golpear` tocava a animacao e parava ali: o bicho levantava a garra, o
## jogador via o ataque acontecer e a vida nao mexia. O unico dano que existia
## vinha da habilidade em area, e ela so roda para `monster_type >= 1` — ou
## seja, o Shiker comum, que e o bicho que o jogador mais encontra, nunca causou
## dano nenhum em toda a existencia do jogo.
##
## Aqui o golpe passa a acertar no meio da animacao, e so se o jogador ainda
## estiver ao alcance: quem sai de perto durante o movimento escapa, que e o que
## faz recuar valer alguma coisa.
const FRACAO_DO_IMPACTO := 0.45
const ALCANCE_DO_CORPO := 2.9

func _marcar_impacto(atraso: float) -> void:
    await get_tree().create_timer(maxf(atraso, 0.05)).timeout
    if _morrendo or not is_instance_valid(self) or _jogador == null:
        return
    if not is_instance_valid(_jogador):
        return
    var perto: float = ALCANCE_DO_CORPO + _altura_do_corpo() * 0.25
    if global_position.distance_to(_jogador.global_position) > perto:
        return
    _bater_no_heroi(_dano_do_corpo)


const ALTURA_SOBRE_A_CABECA := 0.42
var _cabeca: BoneAttachment3D = null
var _suporte_da_barra: Node3D = null

func _prender_na_cabeca() -> void:
    var esqueleto: Skeleton3D = null
    for n in _modelo.find_children("*", "Skeleton3D", true, false):
        esqueleto = n as Skeleton3D
        break
    if esqueleto == null:
        return

    var osso_cabeca := -1
    for nome_osso in ["mixamorig_Head", "Head", "head", "mixamorig:Head"]:
        osso_cabeca = esqueleto.find_bone(nome_osso)
        if osso_cabeca != -1:
            break
    if osso_cabeca == -1:
        return

    _cabeca = BoneAttachment3D.new()
    _cabeca.bone_idx = osso_cabeca
    esqueleto.add_child(_cabeca)


func _seguir_a_cabeca() -> void:
    if _suporte_da_barra == null:
        return
    if _cabeca and is_instance_valid(_cabeca):
        _suporte_da_barra.global_position = _cabeca.global_position + Vector3.UP * ALTURA_SOBRE_A_CABECA
    else:
        _suporte_da_barra.position = _centro_do_corpo + Vector3.UP * (_altura_do_corpo() + 0.3)


const LARGURA_DA_BARRA := 1.25
const ALTURA_DA_BARRA := 0.13
var _barra_cheia: MeshInstance3D

func _construir_barra_vida_3d(cfg: Dictionary) -> void:
    _prender_na_cabeca()

    _suporte_da_barra = Node3D.new()
    _suporte_da_barra.name = "SuporteBarra"
    add_child(_suporte_da_barra)

    _barra_fundo = _quadro(Color(0.04, 0.05, 0.08, 0.95), LARGURA_DA_BARRA + 0.05, ALTURA_DA_BARRA + 0.05, 0)
    _suporte_da_barra.add_child(_barra_fundo)

    # SEM DESLOCAR O NO. O empurrao de meio milimetro em Z vivia na posicao do
    # no, que e medida no espaco do PAI — e o pai nao gira com a camera, so a
    # malha gira. Ao dar meia volta no bicho, esse empurrao passava a apontar
    # para longe de quem olha e enfiava a faixa vermelha atras do fundo escuro.
    # A separacao agora e por prioridade de desenho, que independe de angulo.
    _barra_cheia = _quadro(Color(0.85, 0.18, 0.18, 0.95), LARGURA_DA_BARRA - 0.03, ALTURA_DA_BARRA - 0.03, 1)
    _suporte_da_barra.add_child(_barra_cheia)

    _name_label_3d = Label3D.new()
    _name_label_3d.text = str(cfg.get("nome", "Inimigo"))
    _name_label_3d.font_size = 18
    _name_label_3d.outline_size = 5
    _name_label_3d.modulate = Color(0.98, 0.88, 0.65)
    _name_label_3d.outline_modulate = Color(0.08, 0.02, 0.0, 0.95)
    _name_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _name_label_3d.position.y = 0.22
    _suporte_da_barra.add_child(_name_label_3d)

    _hp_label_3d = Label3D.new()
    _hp_label_3d.text = _texto_da_vida()
    _hp_label_3d.font_size = 13
    _hp_label_3d.outline_size = 4
    _hp_label_3d.modulate = Color(0.95, 0.75, 0.75)
    _hp_label_3d.outline_modulate = Color(0.15, 0.0, 0.0, 0.95)
    _hp_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _hp_label_3d.position.y = -0.16
    _suporte_da_barra.add_child(_hp_label_3d)

    _seguir_a_cabeca()


func _quadro(cor: Color, largura: float, altura: float, prioridade := 0) -> MeshInstance3D:
    var quadro := QuadMesh.new()
    quadro.size = Vector2(largura, altura)

    var material := StandardMaterial3D.new()
    material.albedo_color = cor
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.no_depth_test = false
    # QUEM DESENHA POR CIMA E DECIDIDO AQUI, NAO PELA DISTANCIA.
    #
    # Material transparente nao escreve profundidade, entao a ordem entre o
    # fundo e a faixa vermelha saia do ordenamento por distancia — e as duas
    # estao no mesmo ponto. De alguns angulos o fundo escuro ganhava o desempate
    # e a barra aparecia preta. Com prioridade explicita nao ha desempate.
    material.render_priority = prioridade
    quadro.material = material

    var no := MeshInstance3D.new()
    no.mesh = quadro
    no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return no


func _pintar_barra() -> void:
    if _barra_cheia == null:
        return
    var fracao: float = 0.0 if vida_maxima <= 0.0 else clampf(vida / vida_maxima, 0.0, 1.0)
    var util: float = LARGURA_DA_BARRA - 0.03
    var quadro := _barra_cheia.mesh as QuadMesh
    if quadro == null:
        return
    quadro.size = Vector2(maxf(util * fracao, 0.001), ALTURA_DA_BARRA - 0.03)
    quadro.center_offset = Vector3(-util * (1.0 - fracao) * 0.5, 0.0, 0.0)


func _texto_da_vida() -> String:
    var fase := ("%s  ·  " % _forma_do_cavaleiro) if monster_type == 6 else ""
    return "%s%d / %d" % [fase, int(vida), int(vida_maxima)]


## SO PENSA QUEM ESTA PERTO.
##
## O bicho enxerga o jogador a 10,5 m (RAIO_DE_ATENCAO) e nao decide nada alem
## disso — mas continuava pagando, a cada quadro de fisica, o esqueleto animado,
## o move_and_slide() e a barra de vida colada na cabeca. No mundo aberto as
## zonas vizinhas ficam carregadas junto, entao sao dezenas de bichos animando
## fora da tela para nao fazer nada.
##
## Dormir e so desligar esse custo: nenhum estado se perde, e a folga entre o
## raio de acordar e o de dormir evita o liga-desliga de quem anda na divisa.
const PERTO_PARA_ACORDAR := 34.0
const LONGE_PARA_DORMIR := 44.0
## A vigia e espacada e ganha uma fase propria por bicho, para os ninhos de uma
## regiao nao conferirem a distancia todos no mesmo quadro.
const RITMO_DA_VIGIA := 0.35

var _dormindo := false
var _ate_vigiar := 0.0
## So dorme depois de ter encostado no chao uma vez: dormindo nao ha gravidade,
## e um bicho que nascesse no ar ficaria pendurado ate alguem chegar perto.
var _ja_pisou := false


func _vigiar_distancia(delta: float) -> bool:
    _ate_vigiar -= delta
    if _ate_vigiar <= 0.0:
        _ate_vigiar = RITMO_DA_VIGIA + randf() * 0.12
        var alvo := _achar_jogador()
        if alvo and is_instance_valid(alvo):
            var longe := global_position.distance_to(alvo.global_position)
            if _dormindo:
                if longe < PERTO_PARA_ACORDAR:
                    acordar()
            elif longe > LONGE_PARA_DORMIR and _ja_pisou and not _morrendo:
                _dormir()
    return _dormindo


func _dormir() -> void:
    _dormindo = true
    velocity = Vector3.ZERO
    if _anim_player:
        _anim_player.process_mode = Node.PROCESS_MODE_DISABLED
    if _suporte_da_barra:
        _suporte_da_barra.visible = false


## Publica: quem acerta o bicho de longe (o raio, por exemplo) precisa poder
## trazer de volta um que estava dormindo.
func acordar() -> void:
    if not _dormindo:
        return
    _dormindo = false
    if _anim_player:
        _anim_player.process_mode = Node.PROCESS_MODE_INHERIT
    if _suporte_da_barra:
        _suporte_da_barra.visible = true


func _physics_process(delta: float) -> void:
    if _vigiar_distancia(delta):
        return
    _seguir_a_cabeca()
    if _morrendo:
        return
    if monster_type == 6:
        _manter_no_chao()
    if em_ronda:
        _rondar(delta)
        return
    _pensar_no_golpe(delta)
    _fase += delta
    
    if not is_on_floor():
        velocity.y -= GRAVIDADE * delta
    else:
        velocity.y = -0.5
        _ja_pisou = true
        
    var agora := Time.get_ticks_msec() / 1000.0
    _atualizar_marca_de_controle()
    if agora < _atordoado_ate:
        velocity.x = move_toward(velocity.x, 0.0, 12.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 12.0 * delta)
        move_and_slide()
        return
        
    var alvo := _achar_jogador()
    var desejada := Vector3.ZERO
    _colado_no_jogador = false
    
    if alvo and is_instance_valid(alvo):
        var ate := alvo.global_position - global_position
        ate.y = 0.0
        var dist := ate.length()
        
        if dist < raio_de_atencao and dist > DISTANCIA_DE_PARADA:
            desejada = ate.normalized() * _velocidade * _freio_da_lentidao()
            var target_angle := atan2(ate.x, ate.z)
            rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)
        elif dist <= DISTANCIA_DE_PARADA:
            var target_angle := atan2(ate.x, ate.z)
            rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
            _colado_no_jogador = true
            
    velocity.x = move_toward(velocity.x, desejada.x, 14.0 * delta)
    velocity.z = move_toward(velocity.z, desejada.z, 14.0 * delta)
    move_and_slide()

    var agora_anim := Time.get_ticks_msec() / 1000.0
    if agora_anim < _ataque_ate:
        return

    var passo := Vector2(velocity.x, velocity.z).length()
    if _colado_no_jogador:
        _golpear()
    elif passo > 1.6:
        _tocar("correr")
    elif passo > 0.25:
        _tocar("andar")
    else:
        _tocar("parado")


const AVISO_DO_GOLPE := 1.05
const PAUSA_ENTRE_AREAS := Vector2(3.5, 6.5)
const ALCANCE_DA_AREA := 10.0

var _proxima_area := 3.0
var _raio_da_area := 3.2
var _forca_da_area := 28.0
## O dano do golpe corpo a corpo. Sai da mesma tabela de monstros que ja define
## vida e habilidade — nao e numero novo, e o que sempre esteve la sem uso.
var _dano_do_corpo := 14.0

func _pensar_no_golpe(delta: float) -> void:
    if monster_type == 6:
        _pensar_no_golpe_do_cavaleiro(delta)
        return
    if monster_type < 1 or _morrendo or _jogador == null:
        return
    _proxima_area -= delta
    if _proxima_area > 0.0:
        return
    var ate := _jogador.global_position - global_position
    ate.y = 0.0
    if ate.length() > ALCANCE_DA_AREA:
        return
    _proxima_area = randf_range(PAUSA_ENTRE_AREAS.x, PAUSA_ENTRE_AREAS.y)

    var sorte := randf()
    if (monster_type >= 2 or monster_type >= 4) and sorte < 0.34:
        _raio_em_linha(ate.normalized())
    elif sorte < 0.62:
        _investida(ate.normalized())
    else:
        _marcar_area(_jogador.global_position)


## O circuito da ronda: uma volta lenta em torno do posto, sempre olhando para
## onde vai. Nao usa o jogador para nada — e o que garante que chegar perto nao
## puxa briga sem o desafio ter sido aceito.
## O CHAO DE ULTIMA INSTANCIA, igual ao do heroi.
##
## O chefe e plantado por coordenada quando o mundo monta, e a colisao daquela
## celula pode nascer depois dele. Sem esta rede ele atravessa e cai para
## sempre: medido, 216 metros em tres segundos. `Relevo.altura` e funcao pura de
## (x, z) e sabe onde e o chao mesmo antes de a malha existir.
const QUEDA_QUE_NAO_VOLTA := 3.0

func _manter_no_chao() -> void:
    # O RELEVO VIRA CHAO, e nao rede de resgate.
    #
    # A versao anterior so agia tres metros ABAIXO do terreno e devolvia o corpo
    # meio metro acima dele. A gravidade puxava de novo, ele afundava, era
    # empurrado de novo — um pula-pula. Era isso o "caindo do ceu igual doido"
    # na primeira aproximacao, enquanto a colisao daquela celula ainda nao
    # existe.
    #
    # Agora, quando nao ha piso sob os pes, a propria funcao do relevo faz o
    # papel dele: o corpo pousa na altura certa e para. Com a colisao presente,
    # `is_on_floor` responde e nada disto roda.
    if is_on_floor():
        return
    var chao := Relevo.altura(global_position.x, global_position.z)
    if global_position.y <= chao:
        global_position.y = chao
        velocity.y = 0.0
        _ja_pisou = true


func _rondar(delta: float) -> void:
    _fase_da_ronda += delta * 0.26
    var destino := posto_da_ronda + Vector3(
        cos(_fase_da_ronda) * raio_da_ronda, 0.0, sin(_fase_da_ronda) * raio_da_ronda)
    var ate := destino - global_position
    ate.y = 0.0
    if ate.length() > 0.35:
        var rumo := ate.normalized()
        velocity.x = rumo.x * _velocidade * 0.42
        velocity.z = rumo.z * _velocidade * 0.42
        rotation.y = lerp_angle(rotation.y, atan2(rumo.x, rumo.z), 4.0 * delta)
    else:
        velocity.x = move_toward(velocity.x, 0.0, 8.0 * delta)
        velocity.z = move_toward(velocity.z, 0.0, 8.0 * delta)
    if not is_on_floor():
        velocity.y -= GRAVIDADE * delta
    else:
        velocity.y = -0.5
        _ja_pisou = true
    move_and_slide()
    _manter_no_chao()
    _tocar("andar")


func _pensar_no_golpe_do_cavaleiro(delta: float) -> void:
    if _morrendo or _jogador == null or not is_instance_valid(_jogador):
        return
    if not _apresentou_cavaleiro:
        _apresentou_cavaleiro = true
        _falar("Acordelot ainda chama isto de musica? Mostre-me uma cadencia digna.")
    _proxima_area -= delta
    if _proxima_area > 0.0:
        return
    var ate := _jogador.global_position - global_position
    ate.y = 0.0
    var distancia := ate.length()
    if distancia > 27.0 or distancia < 0.1:
        return
    _proxima_area = randf_range(2.2, 3.7) if _forma_do_cavaleiro == 2 \
        else randf_range(3.4, 5.2)
    var sorte := randf()
    if distancia > 5.0 or sorte < (0.62 if _forma_do_cavaleiro == 2 else 0.42):
        _lancar_corte(ate.normalized())
    elif sorte < 0.78:
        _marcar_area(_jogador.global_position)
    else:
        _investida(ate.normalized())


func _lancar_corte(direcao: Vector3) -> void:
    _tocar("ataque_2", 0.12)
    _ataque_ate = Time.get_ticks_msec() / 1000.0 + 2.15
    if Time.get_ticks_msec() / 1000.0 >= _fala_ate and randf() < 0.34:
        _falar(["Escute o vazio entre as notas.", "Seu ritmo termina aqui.",
            "A dissonancia tambem corta."].pick_random())
    var alvo_guardado := _jogador
    var origem_guardada := global_position + Vector3.UP * 1.25
    await get_tree().create_timer(0.78 if _forma_do_cavaleiro == 1 else 0.58).timeout
    if _morrendo or not is_instance_valid(self):
        return
    var proj: Node3D = ProjetilCavaleiroScript.new()
    get_parent().add_child(proj)
    proj.global_position = origem_guardada + direcao * 1.35
    proj.call("configurar", direcao, _forca_da_area * 0.82, self, alvo_guardado,
        _forma_do_cavaleiro == 2)


func _falar(texto: String) -> void:
    _fala_ate = Time.get_ticks_msec() / 1000.0 + 4.5
    var fala := Label3D.new()
    fala.text = texto
    fala.font_size = 22
    fala.outline_size = 7
    fala.modulate = Color(0.86, 0.78, 1.0)
    fala.outline_modulate = Color(0.04, 0.015, 0.10, 0.98)
    fala.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    fala.no_depth_test = true
    fala.top_level = true
    add_child(fala)
    fala.global_position = global_position + Vector3.UP * 3.35
    var tw := create_tween()
    tw.tween_interval(2.8)
    tw.tween_property(fala, "modulate:a", 0.0, 0.45)
    tw.tween_callback(fala.queue_free)
    var hud := get_tree().get_first_node_in_group("player_hud")
    if hud and hud.has_method("anunciar"):
        hud.anunciar("Cavaleiro — " + texto)


func _marcar_area(onde: Vector3) -> void:
    var raio: float = _raio_da_area * (1.0 + 0.30 * float(monster_type % 3))
    var cor: Color = MONSTROS_CONFIG[monster_type % MONSTROS_CONFIG.size()].get("aura", Color(1, 0.5, 0.2))
    if cor.a <= 0.01:
        cor = Color(1.0, 0.45, 0.2)

    var marca := MeshInstance3D.new()
    var disco := QuadMesh.new()
    disco.size = Vector2(raio * 2.0, raio * 2.0)
    disco.orientation = PlaneMesh.FACE_Y
    disco.center_offset = Vector3(0.0, 0.06, 0.0)
    var material := StandardMaterial3D.new()
    material.albedo_texture = BRILHO
    material.albedo_color = Color(cor.r, cor.g, cor.b, 0.85)
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    disco.material = material
    marca.mesh = disco
    marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    marca.top_level = true
    marca.scale = Vector3(0.35, 1.0, 0.35)
    add_child(marca)
    marca.global_position = Vector3(onde.x, onde.y + 0.05, onde.z)

    var tw := create_tween()
    tw.tween_property(marca, "scale", Vector3.ONE, AVISO_DO_GOLPE)
    tw.tween_callback(_estourar_area.bind(marca.global_position, raio, cor))
    tw.tween_property(material, "albedo_color:a", 0.0, 0.22)
    tw.tween_callback(marca.queue_free)

    if monster_type >= 2:
        _rugir()


func _estourar_area(onde: Vector3, raio: float, cor: Color) -> void:
    if _jogador == null or not is_instance_valid(_jogador):
        return
    var ate := _jogador.global_position - onde
    ate.y = 0.0
    if ate.length() > raio:
        return
    _bater_no_heroi(_forca_da_area + 16.0 * float(monster_type))


func _raio_em_linha(direcao: Vector3) -> void:
    var comprimento := 18.0
    var largura := 2.8
    var origem := global_position + _centro_do_corpo + Vector3.UP * 0.06

    var marca := MeshInstance3D.new()
    var faixa := QuadMesh.new()
    faixa.size = Vector2(largura, comprimento)
    faixa.orientation = PlaneMesh.FACE_Y
    faixa.center_offset = Vector3(0.0, 0.0, -comprimento * 0.5)
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(0.55, 0.85, 1.0, 0.75)
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    faixa.material = material
    marca.mesh = faixa
    marca.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    marca.top_level = true
    marca.scale = Vector3(0.25, 1.0, 1.0)
    add_child(marca)
    marca.global_position = origem
    marca.global_rotation.y = atan2(direcao.x, direcao.z) + PI

    var tw := create_tween()
    tw.tween_property(marca, "scale", Vector3.ONE, AVISO_DO_GOLPE)
    tw.tween_callback(_estourar_linha.bind(origem, direcao, comprimento, largura))
    tw.tween_property(material, "albedo_color:a", 0.0, 0.2)
    tw.tween_callback(marca.queue_free)
    _rugir()


func _estourar_linha(origem: Vector3, direcao: Vector3, comprimento: float, largura: float) -> void:
    if _jogador == null or not is_instance_valid(_jogador):
        return
    var ate := _jogador.global_position - origem
    ate.y = 0.0
    var ao_longo := ate.dot(direcao)
    if ao_longo < 0.0 or ao_longo > comprimento:
        return
    var de_lado := (ate - direcao * ao_longo).length()
    if de_lado > largura * 0.5:
        return
    _bater_no_heroi(_forca_da_area + 20.0 * float(monster_type))


func _investida(direcao: Vector3) -> void:
    var alcance := 10.0
    _tocar("correr", 0.1)
    var tw := create_tween()
    tw.tween_property(self, "velocity", direcao * (_velocidade * 3.2), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tw.tween_callback(func():
        if _jogador == null or not is_instance_valid(_jogador):
            return
        if global_position.distance_to(_jogador.global_position) < 3.0:
            _bater_no_heroi(_forca_da_area * 0.85))


## O DANO NO HEROI ESTAVA CAINDO NO VAZIO.
##
## Isto chamava `receber_dano`, que nao existe em lugar nenhum, e caia no
## `levar_dano` do jogador, que tambem nao existe: os dois `has_method` davam
## falso e o golpe simplesmente sumia. O metodo do HUD sempre se chamou
## `tomar_dano` — o jogo inteiro estava sem dano por causa de um nome.
##
## A defesa entra aqui, com os numeros que o Progresso ja calcula: ela reduz por
## proporcao, nunca zera, e o golpe sempre tira ao menos um risco de vida —
## defesa alta deixa o jogador durar mais, nao virar invulneravel.
func _bater_no_heroi(dano: float) -> void:
    var hud := get_tree().get_first_node_in_group("player_hud")
    if hud == null:
        hud = get_node_or_null("/root/ZonedWorld/HUD/PlayerHUD")
    if hud == null or not hud.has_method("tomar_dano"):
        return
    var progresso := get_node_or_null("/root/Progresso")
    var defesa := 0.0
    if progresso and progresso.has_method("estatisticas"):
        defesa = float(progresso.estatisticas().get("defesa", 0.0))
    var recebido: float = dano * (100.0 / (100.0 + maxf(defesa, 0.0)))
    hud.tomar_dano(maxf(recebido, dano * 0.15))


func _rugir() -> void:
    var onda := MeshInstance3D.new()
    var anel := TorusMesh.new()
    anel.inner_radius = 1.1
    anel.outer_radius = 1.5
    onda.mesh = anel
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 0.55, 0.25, 0.75)
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    onda.material_override = material
    onda.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    onda.position = _centro_do_corpo + Vector3(0.0, 0.6, 0.0)
    add_child(onda)
    var tw := create_tween()
    tw.tween_property(onda, "scale", Vector3(5.0, 1.0, 5.0), 0.55)
    tw.parallel().tween_property(material, "albedo_color:a", 0.0, 0.55)
    tw.tween_callback(onda.queue_free)


func _achar_jogador() -> Node3D:
    if _jogador == null or not is_instance_valid(_jogador):
        _jogador = get_tree().get_first_node_in_group("player") as Node3D
        if _jogador == null:
            _jogador = get_node_or_null("/root/ZonedWorld/Player")
    return _jogador


func levar_dano(quantidade: float, direcao: Vector3) -> void:
    if vida <= 0.0:
        return
    if em_ronda:
        return
    if Time.get_ticks_msec() / 1000.0 < _invulneravel_ate:
        return

    # Levar tiro acorda: o raio alcanca mais longe que o raio de dormir, e um
    # bicho que continuasse dormindo levaria dano sem nunca reagir.
    acordar()

    vida = maxf(0.0, vida - quantidade)
    if _hp_label_3d:
        _hp_label_3d.text = _texto_da_vida()
    _pintar_barra()
        
    _criar_popup_dano(quantidade)
    _avisar_a_barra_do_alvo()
    
    var empurrao := direcao
    empurrao.y = 0.0
    velocity += empurrao.normalized() * EMPURRAO
    _atordoado_ate = Time.get_ticks_msec() / 1000.0 + _atordoamento_maximo
    
    _piscar_dano()
    
    if vida <= 0.0 and monster_type == 6 and _forma_do_cavaleiro == 1:
        _entrar_na_segunda_forma()
    elif vida <= 0.0:
        _morrer()


func _entrar_na_segunda_forma() -> void:
    _forma_do_cavaleiro = 2
    vida = vida_maxima
    _invulneravel_ate = Time.get_ticks_msec() / 1000.0 + 2.1
    _atordoado_ate = _invulneravel_ate
    _ataque_ate = _invulneravel_ate
    _proxima_area = 1.4
    _velocidade *= 1.18
    _forca_da_area *= 1.20
    _dano_do_corpo *= 1.12
    _nome_personalizado = "Cavaleiro da Nota Silenciada  ·  II"
    if _name_label_3d:
        _name_label_3d.text = _nome_personalizado
        _name_label_3d.modulate = Color(0.78, 0.58, 1.0)
    if _aura: _aura.visible = true
    if _fagulhas:
        _fagulhas.visible = true
        _fagulhas.emitting = true
        _fagulhas.amount = 48
    if _hp_label_3d:
        _hp_label_3d.text = _texto_da_vida()
    _pintar_barra()
    _falar("A primeira voz caiu. Agora ouvira a nota que Acordelot tentou apagar.")
    _rugir()


## Controle de grupo leve usado pela classe da Voz. Reusa o mesmo relógio de
## atordoamento da IA e a velocidade existente; não cria estado ou física nova.
## CONTROLE QUE SE VE.
##
## As tres habilidades da Wins ja atordoavam e empurravam desde sempre, e nada
## na tela dizia isso: o bicho parava por dois segundos e o jogador nao tinha
## como saber se foi a habilidade, se travou ou se ele estava so pensando. Uma
## habilidade de controle que nao se anuncia nao existe para quem joga.
##
## Agora o efeito tem NOME e prazo em cima da cabeca, cor propria e uma barra
## que escorre com o tempo restante. `lentidao` e o segundo tipo de controle:
## em vez de parar, o bicho anda devagar — e isso tambem aparece.
func aplicar_controle(duracao: float, direcao := Vector3.ZERO, forca := 0.0,
        lentidao := 0.0, rotulo := "ATORDOADO", cor := Color(0.55, 0.80, 1.0)) -> void:
    var agora := Time.get_ticks_msec() / 1000.0
    if lentidao > 0.0:
        _lentidao = maxf(_lentidao, clampf(lentidao, 0.0, 0.9))
        _lentidao_ate = maxf(_lentidao_ate, agora + maxf(duracao, 0.0))
    else:
        _atordoado_ate = maxf(_atordoado_ate, agora + maxf(duracao, 0.0))
    if direcao.length_squared() > 0.01 and forca > 0.0:
        var plano := direcao
        plano.y = 0.0
        velocity += plano.normalized() * forca
    _mostrar_controle(rotulo, cor, duracao)


var _lentidao := 0.0
var _lentidao_ate := -1.0
var _marca_de_controle: Label3D = null
var _barra_de_controle: MeshInstance3D = null
var _controle_ate := -1.0
var _controle_total := 1.0

func _mostrar_controle(rotulo: String, cor: Color, duracao: float) -> void:
    if _suporte_da_barra == null:
        return
    if _marca_de_controle == null or not is_instance_valid(_marca_de_controle):
        _marca_de_controle = Label3D.new()
        _marca_de_controle.font_size = 15
        _marca_de_controle.outline_size = 5
        _marca_de_controle.outline_modulate = Color(0.02, 0.02, 0.06, 0.95)
        _marca_de_controle.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _marca_de_controle.position.y = 0.30
        _suporte_da_barra.add_child(_marca_de_controle)
        _barra_de_controle = _quadro(cor, LARGURA_DA_BARRA - 0.03, 0.035, 2)
        _barra_de_controle.position.y = 0.20
        _suporte_da_barra.add_child(_barra_de_controle)
    _marca_de_controle.text = rotulo
    _marca_de_controle.modulate = cor
    _marca_de_controle.visible = true
    _barra_de_controle.visible = true
    var mat := (_barra_de_controle.mesh as QuadMesh).material as StandardMaterial3D
    if mat:
        mat.albedo_color = Color(cor.r, cor.g, cor.b, 0.95)
    _controle_total = maxf(duracao, 0.05)
    _controle_ate = Time.get_ticks_msec() / 1000.0 + _controle_total


## Escorre a barrinha do efeito e some quando acaba. Roda junto com a vigia que
## ja existe, entao nao acrescenta um _process por bicho.
func _freio_da_lentidao() -> float:
    if _lentidao <= 0.0:
        return 1.0
    if Time.get_ticks_msec() / 1000.0 >= _lentidao_ate:
        _lentidao = 0.0
        return 1.0
    return 1.0 - _lentidao


func _atualizar_marca_de_controle() -> void:
    if _marca_de_controle == null or not is_instance_valid(_marca_de_controle):
        return
    if not _marca_de_controle.visible:
        return
    var falta: float = _controle_ate - Time.get_ticks_msec() / 1000.0
    if falta <= 0.0:
        _marca_de_controle.visible = false
        _barra_de_controle.visible = false
        return
    var quadro := _barra_de_controle.mesh as QuadMesh
    if quadro:
        var largura: float = (LARGURA_DA_BARRA - 0.03) * clampf(falta / _controle_total, 0.0, 1.0)
        quadro.size = Vector2(maxf(largura, 0.001), 0.035)
        quadro.center_offset = Vector3(
            -(LARGURA_DA_BARRA - 0.03 - largura) * 0.5, 0.0, 0.004)


## VIDA E BRACO CRESCEM EM RITMOS DIFERENTES.
##
## Um so fator para os dois deixava a escolha ruim: subir o bastante para o
## bicho ameacar transformava cada briga numa serragem de dez minutos. O dano
## acompanha o poder do jogador quase por inteiro — e o que faz ter de desviar —
## e a vida acompanha bem menos, para a luta continuar tendo fim.
## CALIBRAGEM POR ALVO, e nao por multiplicador.
##
## Multiplicar a tabela nunca ia fechar: o heroi cresce em ataque E em defesa, e
## a defesa corta o dano recebido pela metade — entao um fator que deixasse o
## bicho ameacador transformava a vida dele numa parede de trinta e sete golpes.
## Aqui a caverna diz o que QUER: quantos golpes este bicho deve aguentar deste
## heroi, e em quantos segundos ele derrubaria este heroi sozinho. Os numeros
## saem disso. Serve para qualquer construcao de personagem, hoje e no nivel 60.
func calibrar(vida_alvo: float, dano_por_golpe: float) -> void:
    var proporcao: float = dano_por_golpe / maxf(_dano_do_corpo, 0.01)
    vida_maxima = maxf(vida_alvo, 1.0)
    vida = vida_maxima
    _dano_do_corpo = dano_por_golpe
    _forca_da_area *= proporcao
    if _hp_label_3d:
        _hp_label_3d.text = _texto_da_vida()
    _pintar_barra()


func ajustar_por_dificuldade(fator_vida: float, fator_dano := -1.0) -> void:
    var dano: float = fator_vida if fator_dano < 0.0 else fator_dano
    vida_maxima *= fator_vida
    vida = vida_maxima
    _forca_da_area *= dano
    _dano_do_corpo *= dano
    if _hp_label_3d:
        _hp_label_3d.text = _texto_da_vida()
    _pintar_barra()


## Marca de chefe. E ela que faz a briga de cinco mil e quatrocentos de vida
## valer alguma coisa alem do drop de um bicho comum.
var _e_chefe := false

func tornar_cavaleiro_chefe() -> void:
    _e_chefe = true
    _nome_personalizado = "Cavaleiro da Nota Silenciada  ·  I"
    vida_maxima = 7200.0
    vida = vida_maxima
    # A ALTURA TEM UM DONO SO: a tabela. Aqui havia um 1,12 por cima dela e o
    # `cavaleiro_chefe.gd` normalizava para outro numero ainda — tres lugares
    # decidindo o mesmo tamanho, e o resultado era 2,58 m quando o pedido era
    # 3,40. Um chefe menor que o Shiker Anciao nao le como chefe.
    scale = Vector3.ONE
    _velocidade = 3.9
    _forca_da_area = 68.0
    _dano_do_corpo = 58.0
    _atordoamento_maximo = 0.08
    if _aura: _aura.visible = false
    if _fagulhas:
        _fagulhas.visible = false
        _fagulhas.emitting = false
    if _name_label_3d:
        _name_label_3d.text = _nome_personalizado
        _name_label_3d.modulate = Color(0.90, 0.82, 1.0)
    if _hp_label_3d:
        _hp_label_3d.text = _texto_da_vida()
    _pintar_barra()

func tornar_super_shiker() -> void:
    _e_chefe = true
    if monster_type >= 3:
        _nome_personalizado = "Colosso Guardião da Caverna"
    else:
        _nome_personalizado = "Super Shiker Ancestral"
    vida_maxima = 5400.0
    vida = vida_maxima
    scale = Vector3.ONE * 1.7
    _velocidade = 4.6
    _forca_da_area = 55.0
    _dano_do_corpo = 42.0
    _atordoamento_maximo = 0.18
    if _name_label_3d:
        _name_label_3d.text = _nome_personalizado
        _name_label_3d.modulate = Color(1.0, 0.50, 0.92)
    if _hp_label_3d:
        _hp_label_3d.text = _texto_da_vida()
    _pintar_barra()


func _avisar_a_barra_do_alvo() -> void:
    var hud := get_tree().get_first_node_in_group("player_hud")
    if hud == null:
        hud = get_node_or_null("/root/ZonedWorld/HUD/PlayerHUD")
    if hud and hud.has_method("mostrar_alvo"):
        var cfg: Dictionary = MONSTROS_CONFIG[monster_type % MONSTROS_CONFIG.size()]
        var nome := _nome_personalizado if not _nome_personalizado.is_empty() else str(cfg.get("nome", "Monstro"))
        hud.mostrar_alvo(nome, vida, vida_maxima)


func _piscar_dano() -> void:
    if not _modelo:
        return
    var tw := create_tween()
    tw.tween_property(_modelo, "position:y", _modelo.position.y + 0.15, 0.08)
    tw.tween_property(_modelo, "position:y", _modelo.position.y, 0.08)


func _criar_popup_dano(qtd: float) -> void:
    var lbl := Label3D.new()
    lbl.text = "-%d" % int(qtd)
    lbl.font_size = 64
    lbl.outline_size = 12
    lbl.modulate = Color(1.0, 0.88, 0.25)
    lbl.outline_modulate = Color(0.35, 0.05, 0.0, 1.0)
    lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    var lado: float = 0.7 if randf() > 0.5 else -0.7
    add_child(lbl)
    if _cabeca and is_instance_valid(_cabeca):
        lbl.top_level = true
        lbl.global_position = _cabeca.global_position + Vector3(lado, 0.15, 0.0)
    else:
        lbl.position = Vector3(lado, float(_altura_do_corpo()) * 0.75, 0.0)

    var tw := create_tween()
    tw.tween_property(lbl, "position:y", lbl.position.y + 0.9, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(lbl, "scale", Vector3.ONE * 0.75, 0.55)
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55).set_delay(0.15)
    tw.tween_callback(lbl.queue_free)


func _altura_do_corpo() -> float:
    var cfg: Dictionary = MONSTROS_CONFIG[monster_type % MONSTROS_CONFIG.size()]
    return float(cfg.get("altura", 2.2))


const CLAVES_POR_FORMA := [[1, 50], [2, 100], [3, 200], [2, 120], [3, 220], [5, 400], [8, 650]]
const MoedaScript := preload("res://scripts/moeda_pve.gd")
const FragmentoDropScript := preload("res://scripts/fragmento_drop.gd")
const CHANCE_DE_FRAGMENTO := [0.25, 0.55, 1.0, 0.45, 0.75, 1.0, 1.0]
const ALTURAS := [
    "do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si",
]

## A EXPERIENCIA VOLTOU A EXISTIR.
##
## `ganhar_experiencia` estava no Progresso desde o comeco e NINGUEM chamava:
## a unica fonte de XP no jogo era gastar Claves numa partitura. Matar bicho
## nao valia nada, e por isso o nivel parou de subir.
##
## O valor sai dos numeros que ja definem o bicho — vida e dano da tabela de
## monstros —, entao um tier mais forte vale mais sem precisar de uma segunda
## tabela para alguem esquecer de atualizar.
## O QUE O CHEFE PAGA.
##
## Ele tinha 5.400 de vida, 55 de dano em area — e largava exatamente o mesmo
## que um Shiker de campo aberto, porque nao existia tabela propria. Pior: o
## Selo do Regente e o Nucleo do Maestro, exigidos na ascensao de nivel 20 e 40,
## NAO EXISTIAM em lugar nenhum do jogo. Nenhum inimigo, nenhum bau, nenhuma
## missao os entregava, e a progressao morria no 20 sem aviso.
##
## Agora nascem aqui: o chefe Shiker guarda o Selo, o Colosso guarda o Nucleo.
## Um por conta: quem ja tem nao recebe de novo, entao nao ha o que farmar — a
## briga vale pelas Claves e pela Alma, e o item de ascensao cai uma vez so.
func _largar_premio_de_chefe() -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null:
        return
    var ganhos: Array[String] = []
    # O Cavaleiro tera um item proprio, ainda em producao. Enquanto ele nao
    # existe, nao rouba o Nucleo do Colosso nem cria um placeholder no save.
    if monster_type != 6:
        var chave := "nucleo_maestro" if monster_type >= 3 else "selo_regente"
        if progresso.quantidade(chave) <= 0:
            progresso.adicionar_recurso(chave, 1)
            ganhos.append("Núcleo do Maestro" if monster_type >= 3 else "Selo do Regente")

    progresso.adicionar_recurso("claves", 900 if monster_type >= 3 else 500)
    ganhos.append("%d Claves" % (900 if monster_type >= 3 else 500))

    # Uma Alma garantida: e a moeda de quem quer completar a escala, e o chefe
    # e o unico lugar onde ela nao depende de sorte.
    var notas: Array = progresso.ECOS.keys()
    if not notas.is_empty():
        var qual := String(notas[randi() % notas.size()])
        progresso.adicionar_recurso("alma_eco_" + qual, 1)
        ganhos.append("Alma de %s" % String(progresso.ECOS[qual]["nome"]))

    var casca := get_tree().root.find_child("UiShell", true, false)
    if casca and casca.has_method("avisar"):
        casca.avisar("Guardião derrotado", ",  ".join(ganhos))
    var hud := get_tree().get_first_node_in_group("player_hud")
    if hud and hud.has_method("anunciar"):
        hud.anunciar("Guardião derrotado — " + ",  ".join(ganhos))


func _dar_experiencia() -> void:
    var progresso := get_node_or_null("/root/Progresso")
    if progresso == null or not progresso.has_method("ganhar_experiencia"):
        return
    var cfg: Dictionary = MONSTROS_CONFIG[monster_type % MONSTROS_CONFIG.size()]
    var xp := int(float(cfg.get("hp", 140.0)) * 0.18 + float(cfg.get("dano", 14.0)) * 1.2)
    if _e_chefe:
        xp *= 12
    if xp <= 0:
        return
    progresso.ganhar_experiencia(xp)

    var aviso := Label3D.new()
    aviso.text = "+%d XP" % xp
    aviso.font_size = 24
    aviso.outline_size = 6
    aviso.modulate = Color(0.62, 0.86, 1.0)
    aviso.outline_modulate = Color(0.02, 0.06, 0.14, 1.0)
    aviso.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    aviso.top_level = true
    add_child(aviso)
    aviso.global_position = global_position + Vector3.UP * 1.9
    var tw := create_tween()
    tw.tween_property(aviso, "global_position:y", aviso.global_position.y + 1.4, 0.9)
    tw.parallel().tween_property(aviso, "modulate:a", 0.0, 0.9)
    tw.tween_callback(aviso.queue_free)


func _largar_clave() -> void:
    var receita: Array = CLAVES_POR_FORMA[monster_type % CLAVES_POR_FORMA.size()]
    var pai := get_parent()
    if pai == null:
        return
    for i in int(receita[0]):
        var moeda: Node3D = MoedaScript.new()
        moeda.valor = int(receita[1])
        var angulo: float = TAU * (float(i) / maxf(float(receita[0]), 1.0)) + randf() * 0.8
        var raio: float = 0.0 if receita[0] == 1 else randf_range(0.55, 1.1)
        # PRIMEIRO ENTRA NA CENA, DEPOIS RECEBE A POSICAO DE MUNDO.
        #
        # Antes o valor de `global_position` do bicho era escrito em `position`,
        # que e LOCAL ao pai. Enquanto o mundo tinha uma zona so, na origem, as
        # duas coisas eram iguais; com o mundo aberto cada regiao vive num
        # deslocamento, e a moeda passou a nascer com o deslocamento somado duas
        # vezes. Medido: 320 metros longe de quem morreu — fora de qualquer
        # alcance de coleta. O drop nunca deixou de acontecer; ele caia longe.
        pai.add_child(moeda)
        moeda.global_position = global_position \
            + Vector3(cos(angulo) * raio, 0.0, sin(angulo) * raio)
        moeda.assentar()


func _largar_fragmento() -> void:
    var forma := monster_type % CHANCE_DE_FRAGMENTO.size()
    if randf() > float(CHANCE_DE_FRAGMENTO[forma]):
        return
    var pai := get_parent()
    if pai == null:
        return
    var fragmento: Node3D = FragmentoDropScript.new()
    fragmento.altura_id = str(ALTURAS.pick_random())
    var angulo := randf() * TAU
    # Mesma correcao da moeda: posicao de MUNDO depois de entrar na cena.
    pai.add_child(fragmento)
    fragmento.global_position = global_position \
        + Vector3(cos(angulo), 0.06, sin(angulo)) * 0.85


func _morrer() -> void:
    remove_from_group("bicho")
    var diario := get_node_or_null("/root/Diario")
    if diario:
        # O prefixo da animacao ja diz que criatura e esta: "shiker" ou "golem".
        diario.registrar("derrotar", 1, _prefixo_anim)
    if not recompensa_controlada_externamente:
        _largar_clave()
        _largar_fragmento()
        _dar_experiencia()
        if _e_chefe:
            _largar_premio_de_chefe()
    derrotado.emit(self)
    if monster_type == 6:
        _falar("Talvez... a proxima nota ainda pertença a voces.")
    _morrendo = true
    if _hp_label_3d: _hp_label_3d.visible = false
    if _name_label_3d: _name_label_3d.visible = false
    if _aura: _aura.visible = false
    if _suporte_da_barra: _suporte_da_barra.visible = false
    if _fagulhas: _fagulhas.emitting = false

    var queda := 0.0
    var anim_morte := _prefixo_anim + "/morte"
    if not _anim_player.has_animation(anim_morte):
        anim_morte = _prefixo_anim + "/morrer"
        
    if _anim_player and _anim_player.has_animation(anim_morte):
        _animacao_atual = "morte"
        _anim_player.play(anim_morte, 0.1)
        queda = _anim_player.get_animation(anim_morte).length

    var tw := create_tween()
    tw.tween_interval(queda + 0.35)
    tw.tween_property(_modelo, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    tw.tween_callback(queue_free)
