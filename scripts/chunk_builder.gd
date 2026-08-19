class_name ChunkBuilder
extends RefCounted
## Monta um pedaco de CHUNK_SIZE metros do mundo: chao + vegetacao.
##
## O mundo tem 110 celulas de 120 m. Montar por celula inteira poria na memoria
## do celular quatro vezes mais mundo do que cabe na tela, entao a unidade de
## carga e o pedaco pequeno — e so entra o que a camera enxerga.
##
## Nada e posicionado a mao: a semente vem da regiao mais as coordenadas do
## pedaco, entao o mesmo pedaco nasce igual toda vez que volta para a tela, e o
## mundo e o mesmo em toda maquina sem guardar milhares de coordenadas.

const CHUNK_SIZE := 30.0
## Um vertice por metro. A colisao de altura do Godot amostra de unidade em
## unidade, entao casar o passo com ela evita escalar a forma — e forma de
## colisao escalada e fonte de tranco no passo do jogador.
const PASSO_DO_CHAO := 1.0
## Os dois triangulos de um quadrado do chao, em ordem de vertice.
const CANTOS := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1),
                 Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]
## Os quatro cantos sem repetir, para testar se o quadrado esta seco.
const CANTOS_DO_QUADRADO := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
## A agua e plana: nao precisa do vertice por metro que a encosta precisa.
const PASSO_DA_AGUA := 2.5
## Praca limpa no centro de cada regiao: e onde da para andar e por NPC.
##
## Encolheu de 11 para 4 m. Onze metros de raio abriam um circulo de mato de 22
## m de diametro em volta do jogador — do alto da camera isso e quase a tela
## inteira vazia, e era o defeito mais visivel do cenario.
const CLEARING_RADIUS := 4.0
## Raio da touceira, em metros. Cinco pes dentro de uns dois metros e o grupo
## que se le como moita; mais aberto que isso volta a virar espalhamento.
const ESPALHAMENTO_DA_TOUCEIRA := 1.3
## Pes por touceira. Arvore e muro continuam sozinhos: floresta em touceira de
## cinco viraria bolo de tronco.
const POR_TOUCEIRA := 5

static var _scene_cache: Dictionary = {}
static var _texture_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
## Centro do pedaco em construcao. A malha e a colisao precisam da coordenada de
## mundo para perguntar a altura, e ambas nascem dentro de build().
static var _centro_em_construcao := Vector3.ZERO
static var _agua: ShaderMaterial = null

## Pelo caminho e nao pelo nome global: o nome so existe depois que o editor
## varre o projeto, e isso quebra exportacao limpa.
const RELEVO := preload("res://scripts/relevo.gd")
static var _prop_material: Material = null

## O TripoSR pinta o modelo em COR POR VERTICE, sem textura. Sem um material que
## leia essa cor como albedo, a arvore chega branca e o ambiente azul do ceu a
## deixa azulada. O material e um so para todo o mundo: alem de corrigir a cor,
## e uma troca de estado a menos por objeto desenhado.
static func prop_material() -> Material:
    if _prop_material == null:
        _prop_material = load("res://Material_TripoSR.tres")
    return _prop_material

## O pedaco e CENTRADO no seu indice, nao apoiado nele. Com a divisa em
## multiplos de 30 m, o centro da celula (multiplo de 120) caia exatamente na
## quina de quatro pedacos: o jogador nascia com meio corpo fora do chao e
## escorregava para fora do mundo antes do primeiro passo.
static func chunk_center(chunk: Vector2i) -> Vector3:
    return Vector3(chunk.x * CHUNK_SIZE, 0.0, chunk.y * CHUNK_SIZE)

static func build(chunk: Vector2i, ground_material: Material) -> Node3D:
    var center := chunk_center(chunk)
    var region := World.region_at(World.cell_at(center))

    _centro_em_construcao = center

    var root := Node3D.new()
    root.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
    root.position = center
    root.add_child(_build_ground(ground_material))
    var agua := _lamina_de_agua()
    if agua:
        root.add_child(agua)

    if region.is_empty():
        return root

    var rng := RandomNumberGenerator.new()
    rng.seed = hash([int(region.get("seed", 0)), chunk.x, chunk.y])

    # As plaquinhas nao viram no na hora: acumulam aqui, por textura, e no fim
    # cada textura sai como UM objeto so com milhares de copias dentro.
    var lotes: Dictionary = {}
    for entry in region.get("props", []):
        _scatter(root, entry, rng, center, lotes)
    _montar_lotes(root, lotes)
    return root

## Junta as plaquinhas de mesma textura num objeto unico.
##
## Cada plaquinha solta e uma chamada de desenho. Para o chao ficar denso como
## nas referencias sao milhares por tela, e milhares de chamadas travam a placa
## alvo por si so, mesmo sendo dois triangulos cada. Agrupadas por textura, o
## pedaco inteiro custa meia duzia de chamadas — o desenho e o mesmo, o preco
## nao e.
static func _montar_lotes(root: Node3D, lotes: Dictionary) -> void:
    var sombras: Array[Transform3D] = []
    for caminho in lotes:
        var poses: Array = lotes[caminho]
        if poses.is_empty():
            continue
        var textura := _load_texture(String(caminho))
        if textura == null:
            continue

        var altura: float = poses[0].get("altura", 1.0)
        var quadro := QuadMesh.new()
        var proporcao := float(textura.get_width()) / float(textura.get_height())
        quadro.size = Vector2(altura * proporcao, altura)
        # O quadrado nasce em volta do centro; subir meia altura poe o pe do
        # mato no chao em vez de enterra-lo ate a metade.
        quadro.center_offset = Vector3(0.0, altura * 0.5, 0.0)
        quadro.material = _material_de_planta(textura)

        var multi := MultiMesh.new()
        multi.transform_format = MultiMesh.TRANSFORM_3D
        multi.mesh = quadro
        multi.instance_count = poses.size()
        for i in poses.size():
            multi.set_instance_transform(i, poses[i]["pose"])

        var no := MultiMeshInstance3D.new()
        no.multimesh = multi
        # Mato nao projeta sombra calculada: sao milhares por tela e cada folha
        # custaria uma passada a mais no mapa de sombras. A sombra vem pintada,
        # logo abaixo.
        no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(no)

        var largura: float = altura * proporcao
        for pose_dados in poses:
            sombras.append(_pose_da_sombra(pose_dados["pose"], largura))

    _montar_sombras(root, sombras)


## A mancha escura debaixo de cada planta.
##
## E o que faz o recorte PERTENCER ao mundo em vez de parecer colado por cima.
## Sem ela o desenho termina numa linha reta encostada na grama, e o olho le
## adesivo — foi exatamente essa a queixa. Nao e sombra de verdade: e uma mancha
## deitada no chao, e sombra calculada para milhares de moitas nao passa na
## placa alvo.
static func _montar_sombras(root: Node3D, poses: Array[Transform3D]) -> void:
    if poses.is_empty():
        return
    var textura := _load_texture("res://textures/sombra_contato.png")
    if textura == null:
        return

    var quadro := QuadMesh.new()
    quadro.size = Vector2.ONE

    var material := StandardMaterial3D.new()
    material.albedo_texture = textura
    # Mistura de verdade, nao recorte: sombra e um degrade, e recorte a
    # transformaria num disco preto com borda serrilhada.
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    # Nao escreve profundidade: sao dezenas de manchas se sobrepondo, e escrever
    # faria uma recortar o degrade da outra em quadrado.
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = quadro
    quadro.material = material
    multi.instance_count = poses.size()
    for i in poses.size():
        multi.set_instance_transform(i, poses[i])

    var no := MultiMeshInstance3D.new()
    no.name = "Sombras"
    no.multimesh = multi
    no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    root.add_child(no)

## Deita a mancha no chao, sob o pe da planta.
static func _pose_da_sombra(pose: Transform3D, largura: float) -> Transform3D:
    # Bem menor que a planta. Do tamanho dela, a mancha vira o objeto mais
    # escuro da cena e o conjunto lembra verruga no campo — foi o que aconteceu.
    var tamanho := largura * absf(pose.basis.get_scale().x) * 0.5
    var deitada := Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3(tamanho, tamanho, 1.0))
    # Tres centimetros acima do chao: colada demais briga com o terreno pelo
    # mesmo pixel e pisca; alta demais descola da planta.
    return Transform3D(deitada, pose.origin + Vector3(0.0, 0.03, 0.0))

static func _material_de_planta(textura: Texture2D) -> StandardMaterial3D:
    if _material_cache.has(textura):
        return _material_cache[textura]
    var material := StandardMaterial3D.new()
    material.albedo_texture = textura
    # Em pe e virado para a camera. Sem travar o eixo Y a moita deita quando o
    # jogador chega perto, porque passa a mirar a camera tambem na vertical.
    material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
    material.billboard_keep_scale = true
    # Transparencia por recorte, nao por mistura. Mistura obriga a ordenar cada
    # moita contra as outras a cada quadro, e moitas que se cruzam piscam
    # trocando de ordem — com recorte o teste de profundidade resolve.
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
    material.alpha_scissor_threshold = 0.5
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    _material_cache[textura] = material
    return material

static func _build_ground(material: Material) -> StaticBody3D:
    var ground := StaticBody3D.new()
    ground.name = "Ground"
    ground.add_child(_malha_do_chao(material))
    ground.add_child(_colisao_do_chao())
    return ground

## O chao como malha dobrada pelo relevo.
##
## Deixou de ser um PlaneMesh: plano nao dobra. Um vertice por metro da encosta
## suave sem escada visivel — e e a MESMA resolucao da colisao, entao o jogador
## nao anda meio palmo acima do que ve.
##
## A malha e local ao pedaco, mas a altura se pergunta em coordenada de MUNDO:
## e o que faz a borda deste pedaco encaixar na do vizinho sem costura, sem
## ninguem precisar conversar com ninguem.
static func _malha_do_chao(material: Material) -> MeshInstance3D:
    var passos := int(CHUNK_SIZE / PASSO_DO_CHAO)
    var meio := CHUNK_SIZE * 0.5
    var centro := _centro_em_construcao

    var malha := SurfaceTool.new()
    malha.begin(Mesh.PRIMITIVE_TRIANGLES)
    for iz in passos:
        for ix in passos:
            var a := Vector2(ix, iz)
            for canto: Vector2 in CANTOS:
                var local: Vector2 = (a + canto) * PASSO_DO_CHAO - Vector2(meio, meio)
                var altura: float = RELEVO.altura(centro.x + local.x, centro.z + local.y)
                malha.set_normal(RELEVO.normal(centro.x + local.x, centro.z + local.y))
                malha.add_vertex(Vector3(local.x, altura, local.y))
    malha.set_material(material)

    var no := MeshInstance3D.new()
    no.name = "Mesh"
    no.mesh = malha.commit()
    # O chao RECEBE sombra mas nao projeta. Encosta grande projetando sobre si
    # mesma da acne de sombra, e a acne desenhava a grade dos pedacos no terreno.
    no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return no

## A lamina de agua do pedaco, ou nada se ali nao houver vale fundo.
##
## Nao ha lago desenhado em lugar nenhum: enche-se o que estiver abaixo de uma
## altura fixa. Isso sai de graca — nenhum dado a mais para carregar — e o lago
## casa com a margem em qualquer regiao, porque agua e terreno saem da mesma
## funcao de altura.
static func _lamina_de_agua() -> MeshInstance3D:
    var passos := int(CHUNK_SIZE / PASSO_DA_AGUA)
    var meio := CHUNK_SIZE * 0.5
    var centro := _centro_em_construcao
    var nivel: float = RELEVO.NIVEL_DA_AGUA

    var malha := SurfaceTool.new()
    malha.begin(Mesh.PRIMITIVE_TRIANGLES)
    var molhou := false

    for iz in passos:
        for ix in passos:
            var a := Vector2(ix, iz)
            # Quadrado inteiro acima da linha da agua nao vira triangulo. Poderia
            # sair transparente, mas transparente ainda custa preenchimento de
            # tela — e a maior parte do mundo e seca.
            var seco := true
            for canto: Vector2 in CANTOS_DO_QUADRADO:
                var l := (a + canto) * PASSO_DA_AGUA - Vector2(meio, meio)
                if RELEVO.altura(centro.x + l.x, centro.z + l.y) < nivel:
                    seco = false
                    break
            if seco:
                continue

            molhou = true
            for canto: Vector2 in CANTOS:
                var local: Vector2 = (a + canto) * PASSO_DA_AGUA - Vector2(meio, meio)
                var fundo: float = RELEVO.altura(centro.x + local.x, centro.z + local.y)
                # A profundidade viaja na cor do vertice. O shader usa para
                # escurecer o meio do lago e por espuma na margem sem precisar
                # ler o buffer de profundidade da tela, que e caro no alvo.
                var quanto := clampf((nivel - fundo) / 3.0, 0.0, 1.0)
                malha.set_color(Color(quanto, quanto, quanto, 1.0))
                malha.set_normal(Vector3.UP)
                malha.add_vertex(Vector3(local.x, nivel, local.y))

    if not molhou:
        return null

    malha.set_material(_material_da_agua())
    var no := MeshInstance3D.new()
    no.name = "Agua"
    no.mesh = malha.commit()
    no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    return no

static func _material_da_agua() -> ShaderMaterial:
    if _agua == null:
        _agua = ShaderMaterial.new()
        _agua.shader = load("res://materials/agua.gdshader")
    return _agua

static func _colisao_do_chao() -> CollisionShape3D:
    var passos := int(CHUNK_SIZE / PASSO_DO_CHAO) + 1
    var meio := CHUNK_SIZE * 0.5
    var centro := _centro_em_construcao

    var forma := HeightMapShape3D.new()
    forma.map_width = passos
    forma.map_depth = passos
    var alturas := PackedFloat32Array()
    alturas.resize(passos * passos)
    for iz in passos:
        for ix in passos:
            alturas[iz * passos + ix] = RELEVO.altura(
                centro.x + ix * PASSO_DO_CHAO - meio,
                centro.z + iz * PASSO_DO_CHAO - meio)
    forma.map_data = alturas

    var no := CollisionShape3D.new()
    no.name = "CollisionShape3D"
    no.shape = forma
    return no

static func _scatter(root: Node3D, entry: Dictionary, rng: RandomNumberGenerator,
                     center: Vector3, lotes: Dictionary) -> void:
    var tag := String(entry.get("tag", ""))
    var kind: Dictionary = World.catalog.get(tag, {})
    if kind.get("models", []).is_empty() and kind.get("sprites", []).is_empty():
        push_warning("Etiqueta sem modelo nem sprite no catalogo: " + tag)
        return

    # A paleta conta props por REGIAO. Aqui cabe a fatia deste pedaco, e a sobra
    # fracionada vira chance — senao toda paleta abaixo de 16 sumiria no zero.
    var per_region: float = float(entry.get("count", 0))
    var chunks_per_region := (World.REGION_SIZE / CHUNK_SIZE) * (World.REGION_SIZE / CHUNK_SIZE)
    var share := per_region / chunks_per_region
    var count := int(floor(share))
    if rng.randf() < share - float(count):
        count += 1
    if count <= 0:
        return

    var half := CHUNK_SIZE * 0.5
    var region_center := World.cell_center(World.cell_at(center))
    var scale_range: Array = kind.get("scale", [1.0, 1.0])
    var sprites: Array = kind.get("sprites", [])
    var altura_do_tipo := float(kind.get("altura", 1.0))

    # Nasce em TOUCEIRA, nao espalhado por igual.
    #
    # Sorteio uniforme poe um pe aqui, um pe ali, sempre mais ou menos a mesma
    # distancia: do alto isso nao le como vegetacao, le como pintinha carimbada
    # no campo. Mato de verdade cresce em grupo, com chao pelado entre um grupo e
    # outro, e e esse contraste de cheio e vazio que da a textura de campo.
    var por_touceira: int = POR_TOUCEIRA if not sprites.is_empty() else 1
    var touceiras := int(ceil(float(count) / float(por_touceira)))

    for t in touceiras:
        var raiz_da_touceira := Vector3(
            rng.randf_range(-half, half), 0.0, rng.randf_range(-half, half))

        for k in por_touceira:
            var offset := raiz_da_touceira
            if por_touceira > 1:
                offset += Vector3(rng.randfn(0.0, ESPALHAMENTO_DA_TOUCEIRA), 0.0,
                                  rng.randfn(0.0, ESPALHAMENTO_DA_TOUCEIRA))
            offset.y = RELEVO.altura(center.x + offset.x, center.z + offset.z)

            # A praca e da REGIAO, entao a distancia se mede do centro dela, nao
            # do pedaco: senao cada pedaco abriria a propria clareira.
            if (center + offset - region_center).length() < CLEARING_RADIUS:
                continue

            var tamanho := rng.randf_range(float(scale_range[0]), float(scale_range[1]))

            if not sprites.is_empty():
                var caminho := String(sprites[rng.randi() % sprites.size()])
                if not lotes.has(caminho):
                    lotes[caminho] = []
                # Plaquinha nao gira em Y: ela ja mira a camera. O sorteio aqui e
                # so espelhar metade delas, que e o que impede o campo de virar
                # carimbo do mesmo desenho repetido.
                var espelho := -1.0 if rng.randf() < 0.5 else 1.0
                lotes[caminho].append({
                    "pose": Transform3D(Basis.IDENTITY.scaled(
                        Vector3(tamanho * espelho, tamanho, tamanho)), offset),
                    "altura": altura_do_tipo,
                })
                continue

            var prop := _criar(kind, rng)
            if prop == null:
                continue
            prop.position = offset + Vector3(0.0, float(kind.get("y", 0.0)), 0.0)
            prop.rotation.y = rng.randf_range(0.0, TAU)
            prop.scale = Vector3.ONE * tamanho
            root.add_child(prop)

            if bool(kind.get("solid", false)):
                PropCollider.apply_to_asset(prop)

static func _criar(kind: Dictionary, rng: RandomNumberGenerator) -> Node3D:
    var models: Array = kind.get("models", [])
    var scene := _load_scene(String(models[rng.randi() % models.size()]))
    if scene == null:
        return null
    var modelo: Node3D = scene.instantiate()
    for mesh_node in modelo.find_children("*", "MeshInstance3D", true, false):
        mesh_node.material_override = prop_material()

    # O modelo entra dentro de um suporte, e quem recebe posicao, giro e escala
    # la fora e o suporte. Assim a correcao de altura viaja junto com a escala
    # sorteada, em vez de brigar com ela.
    var suporte := Node3D.new()
    suporte.name = modelo.name
    suporte.add_child(modelo)
    modelo.position.y = -_base_do_modelo(modelo)
    return suporte

## Onde esta o ponto mais baixo da malha, no espaco do proprio modelo.
##
## Era uma altura fixa por etiqueta no catalogo — 1.7 m para o muro, 2.2 m para
## a arvore. Nao tinha como acertar: os GLB do TripoSR trazem o centro em lugar
## diferente cada um, e a escala ainda e sorteada numa faixa. Numero fixo contra
## escala sorteada da objeto enterrado ou flutuando, e foi o que deu.
static func _base_do_modelo(modelo: Node3D) -> float:
    var caixa := AABB()
    var achou := false
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var local: AABB = _ate_a_raiz(malha, modelo) * malha.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    return caixa.position.y if achou else 0.0

## Transformacao de um no ate a raiz do modelo. A malha costuma estar dois ou
## tres nos abaixo, cada um com o seu deslocamento, e ignorar esse caminho mede
## a caixa no lugar errado.
static func _ate_a_raiz(no: Node3D, raiz: Node3D) -> Transform3D:
    var acumulado := Transform3D.IDENTITY
    var atual: Node3D = no
    while atual != null and atual != raiz:
        acumulado = atual.transform * acumulado
        atual = atual.get_parent() as Node3D
    return acumulado

static func _load_texture(path: String) -> Texture2D:
    if not _texture_cache.has(path):
        _texture_cache[path] = load(path) as Texture2D
    return _texture_cache[path]

static func _load_scene(path: String) -> PackedScene:
    if not _scene_cache.has(path):
        _scene_cache[path] = load(path) as PackedScene
    return _scene_cache[path]
