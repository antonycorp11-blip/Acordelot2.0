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


func _ready() -> void:
    # Bem na frente de quem estiver olhando, senao o motor descarta por estar
    # fora do campo de visao e nao compila nada.
    var camera := get_viewport().get_camera_3d()
    global_position = camera.global_position + camera.global_transform.basis.z * -1.2 if camera else Vector3.ZERO

    _assar_personagem(preload("res://personagem/shiker_base.fbx"),
                      preload("res://personagem/shiker_cor.png"))
    _assar_personagem(preload("res://personagem/mirella_idle.fbx"),
                      preload("res://personagem/mirella_cor.png"))
    _assar_materiais()

    # E deixa modelos de bicho prontos na prateleira, para o primeiro Shiker da
    # partida nao pagar a montagem da malha com esqueleto no meio de uma briga.
    BichoScript.encher_estoque(4)


## Uma malha com esqueleto e textura: e o shader mais caro do jogo e o que o
## primeiro bicho pagava.
func _assar_personagem(cena: PackedScene, pele: Texture2D) -> void:
    var modelo := cena.instantiate()
    var material := StandardMaterial3D.new()
    material.albedo_texture = pele
    material.metallic = 0.0
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        (malha as MeshInstance3D).material_override = material
    modelo.scale = Vector3.ONE * TAMANHO
    add_child(modelo)


## As combinacoes que as skills e as auras usam. Cada linha e uma variante de
## shader que, sem isto, seria compilada no primeiro uso — e o primeiro uso e
## sempre no meio de uma briga.
func _assar_materiais() -> void:
    var receitas := [
        # aditivo sem sombreamento: aura do bicho, halo do poste, poca de luz
        {"add": true, "unshaded": true, "alpha": true, "emissao": false},
        # transparente comum: mira da skill, marcas no chao
        {"add": false, "unshaded": true, "alpha": true, "emissao": false},
        # emissivo iluminado: aura azul do heroi e a espada gigante
        {"add": false, "unshaded": false, "alpha": true, "emissao": true},
        # opaco iluminado com emissao: os props acesos
        {"add": false, "unshaded": false, "alpha": false, "emissao": true},
        # sem sombreamento e OPACO: o orbe que carrega antes do raio sair
        {"add": false, "unshaded": true, "alpha": false, "emissao": false},
    ]
    for receita in receitas:
        var material := StandardMaterial3D.new()
        material.albedo_color = Color(0.4, 0.7, 1.0, 0.5)
        if receita["alpha"]:
            material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        if receita["add"]:
            material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
        if receita["unshaded"]:
            material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        if receita["emissao"]:
            material.emission_enabled = true
            material.emission = Color(0.3, 0.7, 1.0)

        # Duas formas por receita: o motor compila por tipo de malha, e o jogo
        # usa esfera (aura, raio) e quadro (mira, mancha de luz).
        # As quatro formas que o jogo usa: o raio e cilindro, a aura do heroi e
        # anel, o orbe e esfera, e mancha e mira sao quadros.
        for malha in [SphereMesh.new(), QuadMesh.new(), CylinderMesh.new(), TorusMesh.new()]:
            var mi := MeshInstance3D.new()
            mi.mesh = malha
            mi.material_override = material
            mi.scale = Vector3.ONE * TAMANHO
            mi.position = Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0.0)
            mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            add_child(mi)


func _process(_delta: float) -> void:
    _restam -= 1
    if _restam <= 0:
        queue_free()
