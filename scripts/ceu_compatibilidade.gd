extends Node3D
class_name CeuCompatibilidade

## Nuvens, estrelas e lua em geometria barata. O shader de céu customizado não
## funciona de forma confiável no Compatibility/Web — que é o renderizador do
## alvo — então o degradê nativo do ProceduralSkyMaterial continua sendo o céu,
## e o que dá VIDA a ele são estas três malhas.
##
## AS NUVENS ERAM QUARENTA E DUAS ESFERAS.
##
## Esferas lisas e sem sombreamento não parecem nuvem de nenhum ângulo: parecem
## bolhas. E custavam caro pelo motivo errado — 42 esferas de 8x4 segmentos são
## uns 2,7 mil triângulos TRANSPARENTES, e transparência se paga por pixel
## desenhado, não por triângulo.
##
## Agora cada nuvem é UM quadrado virado para a câmera com uma silhueta fofa
## desenhada no canal alfa. Dois triângulos no lugar de sessenta e quatro, a
## mesma chamada de desenho única do MultiMesh, e a borda macia que é justamente
## o que faltava para a coisa ler como nuvem.
##
## A textura é gerada uma vez, em código: um campo de discos suaves somados
## (silhueta de cúmulo, não ruído) com a base levemente acinzentada. Não há
## arquivo para baixar e ela custa poucos milissegundos na abertura.

var ciclo: Node

var _nuvens: MultiMeshInstance3D
var _giro_das_nuvens: Node3D
var _estrelas: MultiMeshInstance3D
var _lua: MeshInstance3D
var _material_nuvens: StandardMaterial3D
var _material_estrelas: StandardMaterial3D
var _material_lua: StandardMaterial3D
var _camera: Camera3D
var _ate_atualizar := 0.0

## Quantas nuvens no total, e quantas sobram em cada nível de qualidade.
##
## Reduzir é só baixar `visible_instance_count`: o MultiMesh já está montado, não
## há nada a reconstruir, e continua sendo uma chamada de desenho. Nenhum nível
## chega a zero — céu vazio parece céu quebrado, e o horizonte é a maior parte do
## que a câmera de ombro enxerga.
const NUVENS_TOTAIS := 34
const NUVENS_POR_NIVEL := [34, 26, 18, 12]

## O plano distante da câmera está em 120 m. Nuvem além disso seria recortada no
## meio; estes raios mantêm a mais longe por volta de 105 m do olho.
const RAIO_MINIMO := 68.0
const RAIO_MAXIMO := 92.0
const ALTURA_MINIMA := 24.0
const ALTURA_MAXIMA := 46.0

## Uma volta inteira em vinte minutos. É lento o bastante para nunca chamar
## atenção e rápido o bastante para o céu não parecer um cenário pintado.
const GIRO_DO_VENTO := TAU / 1200.0


func _ready() -> void:
    _criar_nuvens()
    _criar_estrelas()
    _criar_lua()


func _process(delta: float) -> void:
    if _camera == null:
        _camera = get_viewport().get_camera_3d()
    if _camera:
        global_position.x = _camera.global_position.x
        global_position.z = _camera.global_position.z

    # O vento é o nó inteiro girando devagar, não instância por instância: uma
    # rotação por quadro contra trinta e quatro transformações reescritas.
    # Só as nuvens giram — a lua andando em círculo pelo céu denunciaria o
    # truque, e ela já tem o próprio lugar no horizonte.
    if _giro_das_nuvens:
        _giro_das_nuvens.rotation.y = fposmod(
            _giro_das_nuvens.rotation.y + GIRO_DO_VENTO * delta, TAU)

    _ate_atualizar -= delta
    if _ate_atualizar > 0.0:
        return
    _ate_atualizar = 0.20
    var hora := float(ciclo.hora) if ciclo else 12.0
    var noite := _forca_da_noite(hora)
    _estrelas.visible = noite > 0.06
    _lua.visible = noite > 0.06
    _material_nuvens.albedo_color = Color(
        lerpf(1.0, 0.34, noite), lerpf(1.0, 0.39, noite),
        lerpf(1.0, 0.56, noite), lerpf(0.92, 0.42, noite))
    _material_estrelas.albedo_color.a = noite
    _material_lua.albedo_color.a = noite


## Quantas nuvens o aparelho aguenta. Chamada pelos ajustes gráficos.
##
## Existe porque o ajuste antigo tentava falar com um shader de céu que o
## renderizador do navegador nunca chega a usar: o parâmetro era escrito num
## material nulo e a escolha do jogador não fazia absolutamente nada.
func definir_qualidade(nivel: int) -> void:
    if _nuvens == null or _nuvens.multimesh == null:
        return
    var quantas: int = NUVENS_POR_NIVEL[clampi(nivel, 0, NUVENS_POR_NIVEL.size() - 1)]
    _nuvens.multimesh.visible_instance_count = mini(quantas, NUVENS_TOTAIS)


func _forca_da_noite(hora: float) -> float:
    if hora >= 20.0 or hora <= 4.5:
        return 1.0
    if hora > 18.0:
        return smoothstep(18.0, 20.0, hora)
    if hora < 6.5:
        return 1.0 - smoothstep(4.5, 6.5, hora)
    return 0.0


## A SILHUETA DE UMA NUVEM, desenhada uma vez.
##
## Sete discos suaves somados num campo; onde o campo passa do limiar há nuvem, e
## a passagem é gradual para a borda sair felpuda em vez de recortada. A base
## puxa para o cinza-azulado porque a luz vem de cima: nuvem branca por inteiro
## fica chapada, e essa única sombra já lhe dá volume.
static var _arte_da_nuvem: ImageTexture = null

static func _textura_de_nuvem() -> ImageTexture:
    if _arte_da_nuvem != null:
        return _arte_da_nuvem
    const LADO := 96
    var imagem := Image.create(LADO, LADO, false, Image.FORMAT_RGBA8)
    var sorte := RandomNumberGenerator.new()
    sorte.seed = 20260831
    # Discos em coordenadas de 0 a 1: mais largos no meio, menores nas pontas,
    # e o conjunto achatado na vertical porque cúmulo é mais largo que alto.
    var bolhas: Array = []
    for i in 7:
        var t := float(i) / 6.0
        var altura_da_bolha: float = 0.52 - absf(t - 0.5) * 0.16
        bolhas.append([
            Vector2(0.12 + t * 0.76, altura_da_bolha + sorte.randf_range(-0.05, 0.05)),
            sorte.randf_range(0.12, 0.215) * (1.0 - absf(t - 0.5) * 0.55),
        ])
    for py in LADO:
        var v := (float(py) + 0.5) / float(LADO)
        for px in LADO:
            var u := (float(px) + 0.5) / float(LADO)
            var p := Vector2(u, v)
            var campo := 0.0
            for bolha in bolhas:
                var centro: Vector2 = bolha[0]
                var raio: float = bolha[1]
                var d: float = p.distance_to(centro) / maxf(raio, 0.001)
                if d < 1.0:
                    # Queda suave (1 - d²)²: dá o mesmo perfil arredondado de uma
                    # metabola, sem raiz nem exponencial por pixel.
                    var q := 1.0 - d * d
                    campo += q * q
            var alfa: float = smoothstep(0.34, 0.78, campo)
            # A barriga da nuvem é mais escura que o topo.
            var luz: float = lerpf(0.74, 1.0, smoothstep(0.78, 0.30, v))
            imagem.set_pixel(px, py, Color(luz, luz * 0.99, luz * 0.98 + 0.02, alfa))
    _arte_da_nuvem = ImageTexture.create_from_image(imagem)
    return _arte_da_nuvem


func _criar_nuvens() -> void:
    var folha := QuadMesh.new()
    folha.size = Vector2.ONE

    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    # Sem escrever profundidade: nuvens se atravessam de todo jeito, e escrever
    # faria a de trás sumir num retângulo invisível do tamanho da da frente.
    mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
    # Sem isto o billboard descarta a escala da instância e as trinta e quatro
    # nuvens saem exatamente do mesmo tamanho.
    mat.billboard_keep_scale = true
    mat.albedo_texture = _textura_de_nuvem()
    mat.albedo_color = Color(1.0, 1.0, 1.0, 0.92)
    mat.vertex_color_use_as_albedo = true
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.render_priority = -1
    _material_nuvens = mat
    folha.material = mat

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.use_colors = true
    multi.mesh = folha
    multi.instance_count = NUVENS_TOTAIS

    var rng := RandomNumberGenerator.new()
    rng.seed = 8262026
    # Em BANDOS, não espalhadas por igual: céu real tem trechos carregados e
    # trechos limpos, e distribuição uniforme é o que faz parecer papel de parede.
    var bandos := 7
    for i in NUVENS_TOTAIS:
        var bando := i % bandos
        var dentro := i / bandos
        var angulo := TAU * float(bando) / float(bandos) + rng.randf_range(-0.22, 0.22)
        angulo += float(dentro) * rng.randf_range(-0.13, 0.13)
        var raio := rng.randf_range(RAIO_MINIMO, RAIO_MAXIMO)
        var altura := rng.randf_range(ALTURA_MINIMA, ALTURA_MAXIMA)
        var onde := Vector3(cos(angulo) * raio, altura, sin(angulo) * raio)
        # Largura bem maior que altura: nuvem alta e estreita não existe, e era
        # o que dava o ar de "adesivo mal colocado".
        var largura := rng.randf_range(17.0, 34.0)
        var espessura := largura * rng.randf_range(0.30, 0.46)
        var escala := Basis.IDENTITY.scaled(Vector3(largura, espessura, 1.0))
        multi.set_instance_transform(i, Transform3D(escala, onde))
        # Um sopro de azul nas mais distantes: é a perspectiva aérea, e sozinha
        # já separa a camada de trás da camada da frente.
        var longe: float = (raio - RAIO_MINIMO) / maxf(RAIO_MAXIMO - RAIO_MINIMO, 0.01)
        multi.set_instance_color(i, Color(
            lerpf(1.0, 0.86, longe), lerpf(1.0, 0.90, longe), 1.0,
            lerpf(0.95, 0.66, longe)))

    _giro_das_nuvens = Node3D.new()
    _giro_das_nuvens.name = "VentoDasNuvens"
    add_child(_giro_das_nuvens)

    _nuvens = MultiMeshInstance3D.new()
    _nuvens.name = "Nuvens"
    _nuvens.multimesh = multi
    _nuvens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _giro_das_nuvens.add_child(_nuvens)


func _criar_estrelas() -> void:
    var ponto := SphereMesh.new()
    ponto.radius = 0.15
    ponto.height = 0.3
    ponto.radial_segments = 5
    ponto.rings = 2
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.albedo_color = Color(0.80, 0.90, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.72, 0.84, 1.0)
    mat.emission_energy_multiplier = 3.0
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _material_estrelas = mat
    ponto.material = mat
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = ponto
    # Continua sendo uma única chamada de desenho: aumentar a quantidade de
    # estrelas no MultiMesh quase não altera o custo, mas muda muito a noite.
    multi.instance_count = 180
    var rng := RandomNumberGenerator.new()
    rng.seed = 12011997
    for i in multi.instance_count:
        var angulo := rng.randf_range(0.0, TAU)
        var raio := rng.randf_range(82.0, 101.0)
        var p := Vector3(cos(angulo) * raio, rng.randf_range(20.0, 58.0), sin(angulo) * raio)
        var s := rng.randf_range(0.65, 1.65)
        multi.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), p))
    _estrelas = MultiMeshInstance3D.new()
    _estrelas.name = "Estrelas"
    _estrelas.multimesh = multi
    _estrelas.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_estrelas)


func _criar_lua() -> void:
    var esfera := SphereMesh.new()
    esfera.radius = 3.8
    esfera.height = 7.6
    esfera.radial_segments = 12
    esfera.rings = 6
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.82, 0.90, 1.0)
    mat.emission_enabled = true
    mat.emission = Color(0.60, 0.75, 1.0)
    mat.emission_energy_multiplier = 1.8
    _material_lua = mat
    esfera.material = mat
    _lua = MeshInstance3D.new()
    _lua.name = "Lua"
    _lua.mesh = esfera
    _lua.position = Vector3(-58.0, 42.0, -69.0)
    _lua.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(_lua)
