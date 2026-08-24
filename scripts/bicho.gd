extends CharacterBody3D
class_name Bicho

## As tres formas do Shiker.
##
## Um modelo so, tres bichos. O que muda e escala, atributos e aura — e e de
## proposito: variacao de inimigo comum nao se faz com malha nova, se faz com
## leitura. O jogador precisa saber, a dez metros e sem ler nome nenhum, se
## aquele ali da para enfrentar.
##
## A raridade mora no gerador, nao aqui: quem decide quantos de cada nascem e
## quem os cria.
const MONSTROS_CONFIG := [
    {"nome": "Shiker", "path": "res://personagem/shiker_base.fbx",
     "altura": 1.9, "hp": 120.0, "dano": 12.0, "aura": Color(0, 0, 0, 0), "velocidade": 3.0},
    {"nome": "Shiker Voraz", "path": "res://personagem/shiker_base.fbx",
     "altura": 2.3, "hp": 260.0, "dano": 22.0, "aura": Color(0.95, 0.45, 0.12), "velocidade": 3.4},
    {"nome": "Shiker Ancião", "path": "res://personagem/shiker_base.fbx",
     "altura": 2.9, "hp": 520.0, "dano": 38.0, "aura": Color(0.75, 0.32, 0.98), "velocidade": 3.8},
]

## A textura do gerador do modelo, nao a que o Mixamo devolveu — o auto-rigger
## recomprime a imagem e entrega a pele lavada.
## PRELOAD, nao load.
##
## Era load() na hora em que o bicho nascia, e o primeiro Shiker da partida
## engasgava o jogo: vinte e sete megabytes de malha com esqueleto, a biblioteca
## de animacao e a textura de mil pixels, tudo lido do disco no meio de um
## quadro. Com preload o custo vai para o carregamento do mapa, que e onde o
## jogador ja espera esperar.
const CENA := preload("res://personagem/shiker_base.fbx")
const BIBLIOTECA := preload("res://personagem/shiker_anims.res")
const PELE := preload("res://personagem/shiker_cor.png")
const BRILHO := preload("res://textures/brilho_poste.png")

@export var monster_type: int = 0

var vida_maxima: float = 200.0
var vida: float = 200.0

const VELOCIDADE := 3.2
const RAIO_DE_ATENCAO := 15.0
const DISTANCIA_DE_PARADA := 2.2
const GRAVIDADE := 24.0
const ATORDOAMENTO := 0.4
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
var _aura: MeshInstance3D = null
var _fagulhas: CPUParticles3D = null
var _centro_do_corpo := Vector3.ZERO
var _barra_fundo: MeshInstance3D = null
## O dano de cada forma fica GUARDADO na tabela e ainda nao e aplicado: neste
## sistema o bicho persegue e nao golpeia — quem tira vida do jogador ainda nao
## existe. O numero mora la para o dia em que o golpe entrar, e para a variante
## forte ja nascer forte.
var _velocidade := VELOCIDADE
var _morrendo := false
var _colado_no_jogador := false
var _ataque_ate := -1.0

func _ready() -> void:
    add_to_group("bicho")
    _fase = randf() * TAU
    
    var cfg: Dictionary = MONSTROS_CONFIG[monster_type % MONSTROS_CONFIG.size()]
    vida_maxima = float(cfg.get("hp", 200.0))
    vida = vida_maxima
    _velocidade = float(cfg.get("velocidade", VELOCIDADE))
    
    var forma := CollisionShape3D.new()
    var capsula := CapsuleShape3D.new()
    capsula.radius = 0.75
    capsula.height = float(cfg.get("altura", 2.2))
    forma.shape = capsula
    forma.position.y = capsula.height * 0.5
    add_child(forma)
    
    _construir_modelo(cfg)
    _construir_barra_vida_3d(cfg)

## Modelos ja instanciados, esperando bicho.
##
## Preload resolveu a LEITURA do disco, mas sobrou o custo de montar a cena:
## malha com esqueleto, AnimationPlayer e a arvore de ossos, tudo criado no
## quadro em que o bicho nasce. Com quatro prontos na prateleira desde o
## carregamento, o nascimento vira um add_child.
static var _estoque: Array = []

static func encher_estoque(quantos: int) -> void:
    while _estoque.size() < quantos:
        _estoque.append(CENA.instantiate())


func _construir_modelo(cfg: Dictionary) -> void:
    _modelo = _estoque.pop_back() if not _estoque.is_empty() else CENA.instantiate()
    # Repoe a prateleira DEPOIS do quadro: assim o proximo bicho tambem acha
    # modelo pronto, e a montagem acontece num quadro em que nao nasce ninguem.
    if _estoque.size() < 3:
        # Pelo nome do metodo, sem lambda: a versao com funcao anonima nao passa
        # no analisador desta versao da engine, e um erro de sintaxe aqui derruba
        # a cena inteira — sem ZoneBuilder nao ha chao, e o jogador despenca.
        call_deferred("encher_estoque", 4)
    add_child(_modelo)
    _vestir()
    _preparar_animacoes()
    _assentar(cfg)
    _acender_aura(cfg)


## Leva o bicho a altura que a tabela pede e apoia o pe no chao.
##
## O Mixamo devolve o modelo numa escala propria, e e daqui que sai a diferenca
## entre as tres formas: comum com 1,9 m, voraz com 2,3 e anciao com 2,9. Medir
## a caixa e obrigatorio — altura fixa contra escala desconhecida da bicho
## enterrado ou flutuando, que foi o que aconteceu com a Mirella.
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

    # ONDE O CORPO REALMENTE ESTA, no plano do chao.
    #
    # A malha do Mixamo nao vem centrada na origem do arquivo: e desenhada meio
    # metro para o lado. Como a barra de vida e o nome nasciam na origem do NO,
    # apareciam flutuando ao lado da criatura em vez de sobre a cabeca dela.
    # Guardado aqui, serve para a barra, o nome, a aura e o numero de dano.
    _centro_do_corpo = Vector3(
        (caixa.position.x + caixa.size.x * 0.5) * fator, 0.0,
        (caixa.position.z + caixa.size.z * 0.5) * fator)

    # A pose gravada no arquivo e a T do Mixamo: pes no chao, corpo em pe. E a
    # unica medida confiavel — a caixa da malha com esqueleto NAO acompanha a
    # animacao, entao medir depois, com o bicho ja andando, devolve numero
    # errado. Foi o que fez o Shiker nascer flutuando um metro.


## Poe a pele boa por cima da que veio no FBX.
##
## Sem metal: o exportador grava o fator cheio, e metal puro sem reflexo do
## ambiente aparece PRETO no renderizador de compatibilidade — foi o que
## aconteceu com as casas de enxaimel da vila.
##
## O material FICA GUARDADO: e o mesmo para as tres formas, criado uma vez e
## reaproveitado, para nao remontar material a cada bicho que nasce.
static var _pele_compartilhada: StandardMaterial3D = null

func _vestir() -> void:
    if _pele_compartilhada == null:
        _pele_compartilhada = StandardMaterial3D.new()
        _pele_compartilhada.albedo_texture = PELE
        _pele_compartilhada.metallic = 0.0
        _pele_compartilhada.roughness = 0.9
    # A forma com aura precisa do proprio material, porque a emissao dela e sua;
    # a comum usa o compartilhado e nao gasta nada.
    var pele: StandardMaterial3D = _pele_compartilhada
    if monster_type > 0:
        pele = _pele_compartilhada.duplicate()
    _materials = [pele]
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        (malha as MeshInstance3D).material_override = pele


func _preparar_animacoes() -> void:
    _anim_player = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if _anim_player == null:
        return
    if BIBLIOTECA:
        _anim_player.add_animation_library("shiker", BIBLIOTECA)
        _tocar("parado", 0.0)
    elif not _anim_player.get_animation_list().is_empty():
        _anim_player.play(_anim_player.get_animation_list()[0])


## Troca de animacao so quando MUDA de animacao.
##
## Chamar play() com a mesma de novo reinicia o passo a cada quadro, e o bicho
## anda tremendo no lugar — o tipo de bug que se ve e nao se explica.
func _tocar(nome: String, mistura := 0.2) -> void:
    if _anim_player == null or _animacao_atual == nome:
        return
    if not _anim_player.has_animation("shiker/" + nome):
        return
    _animacao_atual = nome
    _anim_player.play("shiker/" + nome, mistura)


## A aura dos fortes: um disco aceso no chao, aos pes do bicho.
##
## Nao e particula e nao e luz. Particula custa por quadro e por bicho, e luz
## pontual nao pinta o entorno no renderizador de compatibilidade — o mesmo
## motivo pelo qual os postes da vila precisaram de mancha no chao. Um quadrado
## de dois triangulos com mistura aditiva le de longe e nao custa nada.
##
## O comum NAO tem aura, e e isso que faz a aura significar alguma coisa.
func _acender_aura(cfg: Dictionary) -> void:
    var cor: Color = cfg.get("aura", Color(0, 0, 0, 0))
    if cor.a <= 0.01:
        return

    var quadro := QuadMesh.new()
    quadro.size = Vector2(2.6, 2.6) * (1.0 + 0.35 * float(monster_type))
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

    # As fagulhas em volta do corpo.
    #
    # A pele NAO e tingida: aura e o que esta em volta da criatura, nao a cor
    # dela. Pintar o bicho de laranja fazia o forte parecer outro bicho, e nao o
    # mesmo bicho com poder — que e justamente o que se quer ler.
    #
    # CPUParticles3D e nao GPU: no renderizador de compatibilidade o calculo em
    # GPU nao esta disponivel, e vinte particulas por bicho custam menos que a
    # troca de material que estava aqui antes.
    var fagulhas := CPUParticles3D.new()
    fagulhas.name = "Fagulhas"
    fagulhas.amount = 14 + 6 * monster_type
    fagulhas.lifetime = 1.4
    fagulhas.local_coords = true
    # Nascem num anel na altura do peito e sobem devagar, como brasa de fogueira.
    fagulhas.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
    fagulhas.emission_sphere_radius = 0.55 * (1.0 + 0.25 * monster_type)
    fagulhas.position = _centro_do_corpo
    fagulhas.position.y = float(cfg.get("altura", 2.0)) * 0.45
    fagulhas.direction = Vector3.UP
    fagulhas.spread = 25.0
    fagulhas.initial_velocity_min = 0.25
    fagulhas.initial_velocity_max = 0.8
    fagulhas.gravity = Vector3(0.0, 0.35, 0.0)
    fagulhas.scale_amount_min = 0.05
    fagulhas.scale_amount_max = 0.12
    fagulhas.color = cor

    var brasa := StandardMaterial3D.new()
    brasa.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    brasa.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    brasa.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    brasa.vertex_color_use_as_albedo = true
    brasa.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    brasa.albedo_texture = BRILHO
    fagulhas.material_override = brasa
    fagulhas.mesh = QuadMesh.new()
    fagulhas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(fagulhas)
    _fagulhas = fagulhas


## O golpe: por enquanto so a animacao, com pausa entre um e outro.
##
## Encostado no jogador o bicho ficava parado respirando, o que le como bicho
## quebrado. A investida da ritmo a briga — quando o dano do inimigo entrar no
## jogo, e aqui que ele encaixa.
const PAUSA_DO_GOLPE := 1.1

func _golpear() -> void:
    if _anim_player == null or not _anim_player.has_animation("shiker/atacar"):
        _tocar("parado")
        return
    _animacao_atual = "atacar"
    _anim_player.play("shiker/atacar", 0.15)
    _ataque_ate = Time.get_ticks_msec() / 1000.0 \
        + _anim_player.get_animation("shiker/atacar").length + PAUSA_DO_GOLPE


## Prende a barra ao OSSO DA CABECA.
##
## Foram tres tentativas antes desta, e todas erravam pelo mesmo motivo: eu
## calculava onde o corpo estava. Primeiro pela origem do no — mas a malha do
## Mixamo nao nasce centrada nela. Depois pela caixa da malha — mas a caixa e a
## da pose GRAVADA no arquivo, e o Shiker em guarda fica meio metro ao lado
## dela. Depois pelo quadril, medido uma vez — mas ele anda enquanto o bicho
## anda.
##
## BoneAttachment3D nao calcula nada: ele SEGUE o osso, quadro a quadro, com a
## pose que estiver valendo. A barra passa a morar onde a cabeca esta, e nao
## onde eu achava que ela estaria.
##
## O suporte fica fora do modelo escalado, para a barra ter tamanho de barra e
## nao herdar a escala do bicho; quem o leva ate a cabeca e uma copia de
## posicao por quadro, que custa uma soma de vetor.
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

    # O importador do Godot troca os dois-pontos do Mixamo por sublinhado:
    # o osso chama "mixamorig_Head", e nao "mixamorig:Head". Procurar pelo nome
    # errado devolvia -1, o suporte nunca era preso e a barra sumia da tela.
    var osso := -1
    for candidato in ["mixamorig_Head", "mixamorig:Head", "Head",
                      "mixamorig_Hips", "mixamorig:Hips", "Hips"]:
        osso = esqueleto.find_bone(candidato)
        if osso >= 0:
            break
    if osso < 0:
        return

    _cabeca = BoneAttachment3D.new()
    _cabeca.name = "OssoDaCabeca"
    _cabeca.bone_idx = osso
    esqueleto.add_child(_cabeca)


func _seguir_a_cabeca() -> void:
    if _suporte_da_barra == null or _cabeca == null or not is_instance_valid(_cabeca):
        return
    _suporte_da_barra.global_position = _cabeca.global_position + Vector3.UP * ALTURA_SOBRE_A_CABECA


func _ate_a_raiz(no: Node3D, raiz: Node3D) -> Transform3D:
    var acumulado := Transform3D.IDENTITY
    var atual: Node3D = no
    while atual != null and atual != raiz:
        acumulado = atual.transform * acumulado
        atual = atual.get_parent() as Node3D
    return acumulado

## A barra de vida sobre a cabeca, e o nome acima dela.
##
## O numero sozinho — que era o que havia — obriga a LER para saber se o bicho
## esta perto de cair. Barra se entende de relance, no meio da briga, que e
## quando a informacao serve. O numero continua, menor, embaixo dela.
##
## Tudo em quadros deitados com material sem sombreamento e virados para a
## camera: e o mesmo custo de duas moitas, e nao depende de luz nenhuma para ser
## lido de noite.
const LARGURA_DA_BARRA := 0.95
const ALTURA_DA_BARRA := 0.10

var _barra_cheia: MeshInstance3D = null

func _construir_barra_vida_3d(cfg: Dictionary) -> void:
    _prender_na_cabeca()

    # top_level: o suporte ignora a rotacao e a escala do bicho. Sem isso a
    # barra girava junto com a criatura e mudava de tamanho com ela.
    _suporte_da_barra = Node3D.new()
    _suporte_da_barra.name = "Vitais"
    _suporte_da_barra.top_level = true
    add_child(_suporte_da_barra)

    var fundo := _quadro(Color(0.06, 0.03, 0.04, 0.85), LARGURA_DA_BARRA, ALTURA_DA_BARRA)
    _suporte_da_barra.add_child(fundo)
    _barra_fundo = fundo

    _barra_cheia = _quadro(Color(0.85, 0.16, 0.16, 0.95), LARGURA_DA_BARRA - 0.03, ALTURA_DA_BARRA - 0.03)
    _barra_cheia.position.z = 0.01
    _suporte_da_barra.add_child(_barra_cheia)

    _name_label_3d = Label3D.new()
    _name_label_3d.text = str(cfg.get("nome", "Monstro"))
    _name_label_3d.font_size = 17
    _name_label_3d.outline_size = 5
    _name_label_3d.modulate = Color(1.0, 0.9, 0.55)
    _name_label_3d.outline_modulate = Color(0.1, 0.05, 0.02, 0.95)
    _name_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _name_label_3d.position.y = 0.22
    _suporte_da_barra.add_child(_name_label_3d)

    _hp_label_3d = Label3D.new()
    _hp_label_3d.text = "%d / %d" % [int(vida), int(vida_maxima)]
    _hp_label_3d.font_size = 13
    _hp_label_3d.outline_size = 4
    _hp_label_3d.modulate = Color(0.95, 0.75, 0.75)
    _hp_label_3d.outline_modulate = Color(0.15, 0.0, 0.0, 0.95)
    _hp_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _hp_label_3d.position.y = -0.16
    _suporte_da_barra.add_child(_hp_label_3d)

    _seguir_a_cabeca()


## Um retangulo chapado que sempre encara a camera.
func _quadro(cor: Color, largura: float, altura: float) -> MeshInstance3D:
    var quadro := QuadMesh.new()
    quadro.size = Vector2(largura, altura)

    var material := StandardMaterial3D.new()
    material.albedo_color = cor
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.no_depth_test = false
    quadro.material = material

    var no := MeshInstance3D.new()
    no.mesh = quadro
    no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return no


## Encolhe a barra pela esquerda — e faz isso DENTRO DA MALHA.
##
## Aqui estava o defeito que sobrava: o quadro e billboard, ou seja, gira
## sozinho para encarar a camera, mas a POSICAO do no continua presa ao corpo do
## bicho, que tambem gira. Deslocar o no meio metro para a esquerda mandava a
## barra para um lado do MUNDO, nao da tela — e ela aparecia solta, ao lado da
## criatura, virando conforme o bicho se virava.
##
## Mexendo no tamanho e no deslocamento da propria malha, tudo acontece no
## espaco ja girado pelo billboard: a barra encolhe para a esquerda de quem
## olha, sempre, esteja o bicho de frente ou de costas.
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


func _physics_process(delta: float) -> void:
    _seguir_a_cabeca()
    if _morrendo:
        return
    _fase += delta
    
    if not is_on_floor():
        velocity.y -= GRAVIDADE * delta
    else:
        velocity.y = -0.5
        
    var agora := Time.get_ticks_msec() / 1000.0
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
        
        # Persegue o jogador sem causar dano
        if dist < RAIO_DE_ATENCAO and dist > DISTANCIA_DE_PARADA:
            desejada = ate.normalized() * _velocidade
            var target_angle := atan2(ate.x, ate.z)
            rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)
        elif dist <= DISTANCIA_DE_PARADA:
            var target_angle := atan2(ate.x, ate.z)
            rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
            _colado_no_jogador = true
            
    velocity.x = move_toward(velocity.x, desejada.x, 14.0 * delta)
    velocity.z = move_toward(velocity.z, desejada.z, 14.0 * delta)
    move_and_slide()

    # A animacao sai do que o CORPO esta fazendo, nao de um estado guardado a
    # parte. Estado separado sempre acaba discordando do movimento — o bicho
    # deslizando parado e o classico.
    var agora_anim := Time.get_ticks_msec() / 1000.0
    if agora_anim < _ataque_ate:
        return  # deixa o golpe terminar antes de voltar a andar

    var passo := Vector2(velocity.x, velocity.z).length()
    if _colado_no_jogador:
        _golpear()
    elif passo > 1.6:
        _tocar("correr")
    elif passo > 0.25:
        _tocar("andar")
    else:
        _tocar("parado")

## O golpe: por enquanto so a animacao, com pausa entre um e outro.


func _achar_jogador() -> Node3D:
    if _jogador == null or not is_instance_valid(_jogador):
        _jogador = get_tree().get_first_node_in_group("player") as Node3D
        if _jogador == null:
            _jogador = get_node_or_null("/root/ZonedWorld/Player")
    return _jogador

func levar_dano(quantidade: float, direcao: Vector3) -> void:
    if vida <= 0.0:
        return
        
    vida = maxf(0.0, vida - quantidade)
    if _hp_label_3d:
        _hp_label_3d.text = "%d / %d" % [int(vida), int(vida_maxima)]
    _pintar_barra()
        
    _criar_popup_dano(quantidade)
    _avisar_a_barra_do_alvo()
    
    var empurrao := direcao
    empurrao.y = 0.0
    velocity += empurrao.normalized() * EMPURRAO
    _atordoado_ate = Time.get_ticks_msec() / 1000.0 + ATORDOAMENTO
    
    _piscar_dano()
    
    if vida <= 0.0:
        _morrer()

## Acende a barra do alvo no alto da tela.
##
## A barra sobre a cabeca do bicho conta a mesma coisa, mas some no meio da mata
## e fica pequena demais no celular. Esta e a que o jogador realmente le durante
## a briga — e ela so aparece quando ha briga, some sozinha depois.
func _avisar_a_barra_do_alvo() -> void:
    var hud := get_tree().get_first_node_in_group("player_hud")
    if hud == null:
        hud = get_node_or_null("/root/ZonedWorld/HUD/PlayerHUD")
    if hud and hud.has_method("mostrar_alvo"):
        var cfg: Dictionary = MONSTROS_CONFIG[monster_type % MONSTROS_CONFIG.size()]
        hud.mostrar_alvo(str(cfg.get("nome", "Monstro")), vida, vida_maxima)


func _piscar_dano() -> void:
    if not _modelo:
        return
    var tw := create_tween()
    tw.tween_property(_modelo, "position:y", _modelo.position.y + 0.15, 0.08)
    tw.tween_property(_modelo, "position:y", _modelo.position.y, 0.08)

func _criar_popup_dano(qtd: float) -> void:
    var lbl := Label3D.new()
    lbl.text = "-%d" % int(qtd)
    # Mais que o dobro do que era. Numero de dano nao e informacao de leitura
    # cuidadosa: e um golpe de vista no meio da briga, e a vinte e oito ele
    # sumia contra o mato.
    lbl.font_size = 64
    lbl.outline_size = 12
    lbl.modulate = Color(1.0, 0.88, 0.25)
    lbl.outline_modulate = Color(0.35, 0.05, 0.0, 1.0)
    lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    # Do LADO da cabeca, nao em cima dela: centrado, o numero grande cobria o
    # bicho justamente no momento em que se quer ver o que ele esta fazendo.
    var lado: float = 0.7 if randf() > 0.5 else -0.7
    if _cabeca and is_instance_valid(_cabeca):
        lbl.top_level = true
        lbl.global_position = _cabeca.global_position + Vector3(lado, 0.15, 0.0)
    else:
        lbl.position = Vector3(lado, float(_altura_do_corpo()) * 0.75, 0.0)
    add_child(lbl)

    # Sobe pouco e sai rapido: meio segundo basta para ler, e mais que isso
    # deixa tres numeros empilhados quando o golpe e em sequencia.
    var tw := create_tween()
    tw.tween_property(lbl, "position:y", lbl.position.y + 0.9, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(lbl, "scale", Vector3.ONE * 0.75, 0.55)
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55).set_delay(0.15)
    tw.tween_callback(lbl.queue_free)


func _altura_do_corpo() -> float:
    var cfg: Dictionary = MONSTROS_CONFIG[monster_type % MONSTROS_CONFIG.size()]
    return float(cfg.get("altura", 2.2))

## O que cada forma larga: quantas claves e quanto vale cada uma.
##
## Duas ou tres no chao e melhor que uma so — recompensa que se espalha rende
## aquele instante de catar, e o ima recolhe todas de uma vez quando o jogador
## passa. Mais que tres nao entra: o modelo tem cinquenta mil triangulos, e um
## punhado delas custa mais caro que o bicho que as largou.
##
##                     quantas, quanto vale cada
const CLAVES_POR_FORMA := [[1, 50], [2, 100], [3, 200]]
const MoedaScript := preload("res://scripts/moeda_pve.gd")
const FragmentoDropScript := preload("res://scripts/fragmento_drop.gd")
const CHANCE_DE_FRAGMENTO := [0.22, 0.55, 1.0]
const ALTURAS := [
    "do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si",
]

func _largar_clave() -> void:
    var receita: Array = CLAVES_POR_FORMA[monster_type % CLAVES_POR_FORMA.size()]
    var pai := get_parent()
    if pai == null:
        return
    for i in int(receita[0]):
        var moeda: Node3D = MoedaScript.new()
        moeda.valor = int(receita[1])
        # Espalhadas em volta de onde o bicho caiu, nunca uma dentro da outra.
        var angulo: float = TAU * (float(i) / maxf(float(receita[0]), 1.0)) + randf() * 0.8
        var raio: float = 0.0 if receita[0] == 1 else randf_range(0.55, 1.1)
        moeda.position = global_position + Vector3(cos(angulo) * raio, 0.0, sin(angulo) * raio)
        # No pai, nao em si: o bicho vai sumir em seguida e levaria a moeda junto.
        pai.add_child(moeda)


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
    fragmento.position = global_position + Vector3(cos(angulo), 0.06, sin(angulo)) * 0.85
    # No pai, porque o corpo do Shiker desaparece depois da animacao de morte.
    pai.add_child(fragmento)


func _morrer() -> void:
    remove_from_group("bicho")
    _largar_clave()
    _largar_fragmento()
    _morrendo = true
    if _hp_label_3d: _hp_label_3d.visible = false
    if _name_label_3d: _name_label_3d.visible = false
    if _aura: _aura.visible = false
    if _suporte_da_barra: _suporte_da_barra.visible = false
    if _fagulhas: _fagulhas.emitting = false

    # Cai antes de sumir. O encolhimento sozinho — o que havia aqui — lia como
    # o bicho sendo sugado para dentro do chao; agora ele tomba, fica um
    # instante no chao e so entao desaparece.
    var queda := 0.0
    if _anim_player and _anim_player.has_animation("shiker/morrer"):
        _animacao_atual = "morrer"
        _anim_player.play("shiker/morrer", 0.1)
        queda = _anim_player.get_animation("shiker/morrer").length

    var tw := create_tween()
    tw.tween_interval(queda + 0.35)
    tw.tween_property(_modelo, "scale", Vector3.ZERO, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    tw.tween_callback(queue_free)
