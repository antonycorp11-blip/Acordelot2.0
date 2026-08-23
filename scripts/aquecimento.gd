extends Node3D
class_name Aquecimento
## Compila os shaders do jogo ANTES de o jogador precisar deles.
##
## O engasgo tinha duas causas somadas, e esta e a segunda. A primeira era ler
## malha e textura do disco na hora do nascimento — resolvida com preload nos
## scripts do bicho e da NPC. Esta e mais teimosa: no renderizador de
## compatibilidade o motor so COMPILA o shader de um material quando ele aparece
## na tela pela primeira vez. Cada combinacao nova — pele com esqueleto, quadro
## aditivo, malha sem sombreamento — e uma compilacao no meio do quadro, e e
## isso que trava o jogo quando o primeiro Shiker surge ou a primeira skill sai.
##
## O truque e mostrar cada combinacao por alguns quadros, minuscula e na frente
## da camera, enquanto a tela de carregamento ainda esta no ar. Compilado uma
## vez, o shader vale para toda a sessao.
##
## Nao e esconder o problema com espera: o custo continua existindo, so que pago
## no carregamento, que e onde o jogador ja esta esperando.

## Quantos quadros as pecas ficam desenhadas. Um so nao basta: o motor enfileira
## a compilacao e ela acontece no desenho seguinte.
const QUADROS := 6
## Tamanho das pecas de teste. Pequenas o bastante para ninguem ver, grandes o
## bastante para nao serem descartadas antes de desenhar.
const TAMANHO := 0.04

## Pelo caminho, nao pelo nome global: o nome so existe depois que o editor
## varre o projeto, e isso quebra exportacao limpa.
const BichoScript := preload("res://scripts/bicho.gd")

var _restam := QUADROS


const NpcScript := preload("res://scripts/npc.gd")
const MoedaScript := preload("res://scripts/moeda_pve.gd")

var _descartaveis: Array[Node] = []


func _ready() -> void:
    # Bem na frente de quem estiver olhando: fora do campo de visao o motor
    # descarta antes de desenhar, e sem desenhar nao ha compilacao.
    var camera := get_viewport().get_camera_3d()
    if camera:
        global_position = camera.global_position + camera.global_transform.basis.z * -1.4

    _assar_bichos()
    _assar_moradores()
    _assar_skills()
    _assar_animacoes_do_heroi()

    BichoScript.encher_estoque(4)


## OS BICHOS DE VERDADE, nao imitacoes deles.
##
## A tentativa anterior montava materiais parecidos e nao adiantou: o motor
## compila por configuracao exata — pele com esqueleto, quadro aditivo da aura,
## particula de fagulha, numero flutuante do dano. Cada detalhe diferente e
## outro shader. Instanciar o proprio Shiker resolve porque nao ha o que
## adivinhar: e o mesmo caminho de codigo que roda quando ele nasce na briga.
##
## Fica sem fisica e fora do grupo "bicho": e um manequim, nao um inimigo, e
## some depois de alguns quadros.
func _assar_bichos() -> void:
    for tipo in 3:
        var bicho: Node3D = BichoScript.new()
        bicho.monster_type = tipo
        add_child(bicho)
        bicho.set_physics_process(false)
        bicho.remove_from_group("bicho")
        bicho.scale = Vector3.ONE * TAMANHO
        _descartaveis.append(bicho)

    # A clave que eles largam: malha, emissao e o halo aditivo.
    var moeda: Node3D = MoedaScript.new()
    add_child(moeda)
    moeda.set_process(false)
    moeda.scale = Vector3.ONE * TAMANHO
    _descartaveis.append(moeda)

    # O numero de dano que sobe na cabeca do bicho tem shader proprio.
    var numero := Label3D.new()
    numero.text = "-000"
    numero.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    numero.font_size = 28
    numero.outline_size = 6
    numero.scale = Vector3.ONE * TAMANHO
    add_child(numero)
    _descartaveis.append(numero)


func _assar_moradores() -> void:
    var mirella: Node3D = NpcScript.new()
    add_child(mirella)
    mirella.set_physics_process(false)
    mirella.remove_from_group("npc")
    mirella.scale = Vector3.ONE * TAMANHO
    _descartaveis.append(mirella)


## As tres skills, montadas como o heroi as monta.
##
## A aura azul sai do proprio heroi, chamando a funcao que a desenha — o buff
## nao e ativado, so o visual e construido. O raio e o orbe sao remontados aqui
## com os mesmos tipos de malha e material do disparo.
func _assar_skills() -> void:
    var heroi := get_tree().get_first_node_in_group("heroi")
    if heroi == null:
        heroi = get_node_or_null("/root/ZonedWorld/Player/Hero")
    if heroi and heroi.has_method("_criar_aura_azul_visual"):
        heroi.call("_criar_aura_azul_visual")
        var fx = heroi.get("_aura_fx_node")
        if fx:
            _descartaveis.append(fx)

    # O feixe: cilindro sem sombreamento com alfa, mais a luz que o acompanha.
    var feixe := MeshInstance3D.new()
    var cilindro := CylinderMesh.new()
    cilindro.top_radius = 0.4
    cilindro.bottom_radius = 0.4
    feixe.mesh = cilindro
    var mat_feixe := StandardMaterial3D.new()
    mat_feixe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_feixe.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat_feixe.albedo_color = Color(0.4, 0.9, 1.0, 0.8)
    feixe.material_override = mat_feixe
    feixe.scale = Vector3.ONE * TAMANHO
    add_child(feixe)
    _descartaveis.append(feixe)

    var luz := OmniLight3D.new()
    luz.omni_range = 2.0
    luz.light_energy = 0.6
    add_child(luz)
    _descartaveis.append(luz)

    # O orbe que carrega antes do tiro: esfera sem sombreamento e OPACA, que e
    # outra variante de shader.
    var orbe := MeshInstance3D.new()
    orbe.mesh = SphereMesh.new()
    var mat_orbe := StandardMaterial3D.new()
    mat_orbe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat_orbe.albedo_color = Color(0.4, 0.9, 1.0, 0.95)
    orbe.material_override = mat_orbe
    orbe.scale = Vector3.ONE * TAMANHO
    add_child(orbe)
    _descartaveis.append(orbe)


## O ataque basico travava na PRIMEIRA vez por outro motivo: a animacao nunca
## tinha rodado, e a primeira execucao monta o cache de trilhas do
## AnimationPlayer — sete animacoes de esqueleto, no meio do primeiro golpe.
##
## Aqui cada uma avanca zero segundo e para. O corpo nao se mexe na tela e o
## cache fica pronto.
func _assar_animacoes_do_heroi() -> void:
    var heroi := get_node_or_null("/root/ZonedWorld/Player/Hero")
    if heroi == null:
        return
    var animador := heroi.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if animador == null:
        return
    var guardada := animador.current_animation
    for nome in animador.get_animation_list():
        animador.play(nome)
        animador.advance(0.0)
    animador.stop()
    if guardada != "":
        animador.play(guardada)


func _process(_delta: float) -> void:
    _restam -= 1
    if _restam > 0:
        return
    # Os manequins somem; os shaders deles ficam compilados pelo resto da
    # sessao, que e a coisa toda.
    for no in _descartaveis:
        if is_instance_valid(no):
            no.queue_free()
    queue_free()
