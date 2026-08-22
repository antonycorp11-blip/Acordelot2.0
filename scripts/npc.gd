extends Node3D
class_name Npc
## Uma moradora da vila: malha, respiro, uma volta pelo bairro e raio de conversa.
##
## A rotina e de proposito burra — parar, escolher um ponto perto, ir ate la,
## parar de novo. Nao ha rota, nao ha desvio, nao ha hora de dormir. Uma NPC de
## vila precisa parecer que mora ali, e para isso bastam passos de vez em
## quando; caminho calculado e patrulha sao problema de quem tem guarda e
## inimigo, e nao e o caso aqui.
##
## A malha vem do FBX de respiro; o movimento vem da biblioteca assada ao lado.
## O FBX de caminhada trazia a malha inteira outra vez — 29 MB para nove
## segundos de passo.

## O Mixamo devolve o modelo numa escala propria. 1,68 m e a altura que casa com
## o heroi de 1,75 e com as portas das casas da vila.
const ALTURA_ALVO := 1.68
## Onde o botao de conversar aparece. Tres metros e perto o bastante para ser
## claro de quem se trata e longe o bastante para nao precisar encostar nela.
const RAIO_DE_CONVERSA := 3.2

## A CALCADA E A RUA, nao um circulo qualquer.
##
## Antes o destino era sorteado num raio de doze metros, e doze metros a partir
## do largo cobrem parede de casa, poste, poco e cerca — ela atravessava tudo,
## porque NPC nao tem corpo de fisica aqui. A area agora e o corredor da via,
## que o planejador deixa vazio de proposito: nao ha o que atravessar dentro
## dele, e nao e preciso navegacao nenhuma para garantir isso.
##
## E em metros do mundo, medido do centro da zona.
@export var area_x := Vector2(-3.4, 3.4)
@export var area_z := Vector2(-13.0, 13.0)

## Passo de quem mora ali, nao de quem esta com pressa.
const VELOCIDADE := 0.85
## A que velocidade a animacao de caminhada avanca no chao, no tamanho dela.
## E daqui que sai o ritmo do passo: com a animacao correndo no tempo original e
## o corpo a 0,85 m/s, os pes patinavam no chao a cada passada.
const PASSO_DA_ANIMACAO := 1.45
## Quanto tempo ela fica parada entre uma caminhada e outra. Faixa larga de
## proposito: pausa fixa vira metronomo e o olho percebe o padrao.
const PAUSA := Vector2(3.0, 8.0)
## Giro suave. A quatro radianos por segundo ela pivotava no lugar como torre de
## tanque; a dois e meio o corpo acompanha a curva.
const GIRO_POR_SEGUNDO := 2.5
## Ela so anda depois de estar mais ou menos virada para onde vai — senao anda
## de lado nos primeiros passos, que e a parte que mais parecia quebrada.
const ANGULO_PARA_ANDAR := 0.55

signal jogador_chegou(npc: Npc)
signal jogador_saiu(npc: Npc)

## PRELOAD, nao load: a Mirella nasce junto com a zona, e ler malha, animacao e
## textura do disco no meio do quadro era um engasgo na cara do jogador.
const CENA := preload("res://personagem/mirella_idle.fbx")
const BIBLIOTECA := preload("res://personagem/mirella_anims.res")
const PELE := preload("res://personagem/mirella_cor.png")

## Um material so para todas as Mirellas que existirem.
static var _pele_compartilhada: StandardMaterial3D = null

@export var nome := "Mirella"
@export var modelo_path := "res://personagem/mirella_idle.fbx"
## A textura ORIGINAL da personagem.
##
## A que veio no FBX do Mixamo e uma reassada que perdeu o rosto — o auto-rigger
## recomprime a imagem e devolve a pele lavada. Esta e a que saiu do gerador do
## modelo, e o UV e o mesmo, entao trocar so a imagem basta.
@export var textura_path := "res://personagem/mirella_cor.png"
@export var animacoes_path := "res://personagem/mirella_anims.res"
@export var dialogo := "mirella_boas_vindas"
## NPC de missao fica no lugar marcado. Quem espera o jogador num ponto nao pode
## estar do outro lado da praca quando ele chegar.
@export var fixa := false

var _animador: AnimationPlayer
var _perto := false
var _casa := Vector3.ZERO
var _alvo := Vector3.ZERO
var _andando := false
var _espera := 0.0
var _conversando := false
var _animacao_atual := ""
var _terreno: Node = null


func _ready() -> void:
    # O jogo encontra os NPCs pelo grupo depois que a zona nasce — sao criados
    # junto com o cenario, entao nao ha como liga-los uma vez so no comeco.
    add_to_group("npc")
    _casa = position
    _espera = randf_range(PAUSA.x, PAUSA.y)

    var modelo := CENA.instantiate()
    add_child(modelo)
    _vestir(modelo)
    _assentar(modelo)

    _animador = modelo.find_child("AnimationPlayer", true, false)
    if _animador:
        if BIBLIOTECA:
            _animador.add_animation_library("mirella", BIBLIOTECA)
            _tocar("parado")
        else:
            var lista := _animador.get_animation_list()
            if lista.size() > 0:
                _animador.play(lista[0])

    _montar_area()
    set_physics_process(not fixa)


## Troca a imagem do Mixamo pela original, mantendo o resto do material.
func _vestir(modelo: Node3D) -> void:
    # Um material so, guardado: cada Mirella nova reaproveita o mesmo em vez de
    # montar outro — material novo e variante de shader nova para o motor.
    if _pele_compartilhada == null:
        _pele_compartilhada = StandardMaterial3D.new()
        _pele_compartilhada.albedo_texture = PELE
        # Sem metal: o FBX chega com o fator do exportador, e metal puro sem
        # reflexo do ambiente aparece preto no renderizador de compatibilidade.
        _pele_compartilhada.metallic = 0.0
        _pele_compartilhada.roughness = 0.9
    var pele := _pele_compartilhada
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        (malha as MeshInstance3D).material_override = pele


## Poe o PE dela no chao, nao a origem do arquivo.
##
## Era so escalar pela altura e pronto, e por isso ela flutuava: o Mixamo grava
## a origem do modelo na cintura ou abaixo dos pes conforme o exportador, e a
## distancia entre a origem e a sola muda de arquivo para arquivo. Medir a caixa
## e descontar o pe dela e o que funciona para qualquer modelo — e a mesma conta
## que o construtor de cenario faz com as casas.
func _assentar(modelo: Node3D) -> void:
    var caixa := AABB()
    var achou := false
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        var local: AABB = mi.transform * mi.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    if not achou or caixa.size.y <= 0.001:
        return
    var fator: float = ALTURA_ALVO / caixa.size.y
    modelo.scale = Vector3.ONE * fator
    modelo.position.y = -caixa.position.y * fator


## O raio de conversa, como area de fisica.
##
## Area3D e nao distancia medida a cada quadro: o motor ja faz essa conta uma vez
## por par de corpos, e uma NPC parada nao precisa de um _process seu so para
## perguntar "ja chegou?" sessenta vezes por segundo.
func _montar_area() -> void:
    var area := Area3D.new()
    area.name = "RaioDeConversa"
    area.collision_layer = 0
    area.monitorable = false

    var forma := CollisionShape3D.new()
    var esfera := SphereShape3D.new()
    esfera.radius = RAIO_DE_CONVERSA
    forma.shape = esfera
    forma.position.y = 1.0
    area.add_child(forma)

    area.body_entered.connect(func(corpo: Node3D):
        if _perto or not corpo.is_in_group("jogador"):
            return
        _perto = true
        jogador_chegou.emit(self))
    area.body_exited.connect(func(corpo: Node3D):
        if not _perto or not corpo.is_in_group("jogador"):
            return
        _perto = false
        jogador_saiu.emit(self))
    add_child(area)


# -------------------------------------------------------------
# A rotina
# -------------------------------------------------------------
func _physics_process(delta: float) -> void:
    if _conversando:
        return

    if not _andando:
        _espera -= delta
        if _espera <= 0.0:
            _escolher_destino()
        return

    var passo := _alvo - position
    passo.y = 0.0
    if passo.length() < 0.45:
        _parar()
        return

    var direcao := passo.normalized()
    var desejado := atan2(direcao.x, direcao.z)
    rotation.y = rotate_toward(rotation.y, desejado, GIRO_POR_SEGUNDO * delta)

    # Anda so quando ja esta olhando para la. Enquanto vira, fica no lugar
    # girando — e o que uma pessoa faz antes de sair andando.
    var diferenca: float = absf(angle_difference(rotation.y, desejado))
    if diferenca > ANGULO_PARA_ANDAR:
        _tocar("parado")
        return

    position += direcao * VELOCIDADE * delta
    _colar_no_chao()
    _tocar("andar")


## Um ponto qualquer DENTRO do corredor da via, longe o bastante para valer a
## caminhada — destino a meio metro daria um passo e uma parada.
func _escolher_destino() -> void:
    for tentativa in 8:
        var candidato := Vector3(
            randf_range(area_x.x, area_x.y), 0.0,
            randf_range(area_z.x, area_z.y))
        if candidato.distance_to(position) >= 3.0:
            _alvo = candidato
            _andando = true
            return
    # Sem candidato bom (ela esta no meio de uma area pequena): espera mais um
    # pouco em vez de sair andando meio metro.
    _espera = randf_range(PAUSA.x, PAUSA.y)


func _parar() -> void:
    _andando = false
    _espera = randf_range(PAUSA.x, PAUSA.y)
    _tocar("parado")


## Troca de animacao so quando MUDA, e com o passo no ritmo do corpo.
##
## Tocar de novo a mesma animacao a cada quadro reinicia o passo e o corpo anda
## tremendo. E a velocidade da caminhada e ajustada para os pes acompanharem o
## chao: animacao no tempo original com corpo devagar e o classico "patinando".
func _tocar(nome: String) -> void:
    if _animador == null or _animacao_atual == nome:
        return
    if not _animador.has_animation("mirella/" + nome):
        return
    _animacao_atual = nome
    _animador.speed_scale = (VELOCIDADE / PASSO_DA_ANIMACAO) if nome == "andar" else 1.0
    _animador.play("mirella/" + nome, 0.35)


## Mantem a sola no relevo enquanto ela anda.
##
## O terreno da zona nao e plano: e uma malha dobrada, e uma NPC que anda numa
## altura fixa afunda na subida e flutua na descida. Quem sabe a altura de cada
## ponto e o construtor da zona, que a calcula por formula — mais barato que um
## raio de fisica por quadro.
func _colar_no_chao() -> void:
    if _terreno == null:
        var p := get_parent()
        while p != null and not p.has_method("calcular_altura"):
            p = p.get_parent()
        _terreno = p
    if _terreno:
        position.y = _terreno.calcular_altura(position.x, position.z)


func _virar_para(direcao: Vector3, delta: float) -> void:
    var desejado := atan2(direcao.x, direcao.z)
    rotation.y = rotate_toward(rotation.y, desejado, GIRO_POR_SEGUNDO * delta)


## Vira o rosto para quem chegou. So o eixo Y: NPC que inclina para olhar o
## jogador de cima parece que vai cair.
func olhar_para(alvo: Vector3) -> void:
    var direcao := alvo - global_position
    direcao.y = 0.0
    if direcao.length_squared() < 0.01:
        return
    rotation.y = atan2(direcao.x, direcao.z)


## Enquanto a caixa de conversa esta aberta ela nao sai andando: a fala ficaria
## saindo de alguem que ja esta do outro lado da rua.
func parar_para_conversar() -> void:
    _conversando = true
    _andando = false
    _tocar("parado")


func voltar_a_rotina() -> void:
    _conversando = false
    _espera = randf_range(PAUSA.x, PAUSA.y)
