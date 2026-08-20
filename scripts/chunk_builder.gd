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

## Se as lampadas do mundo estao acesas. Quem manda e o ciclo do dia; fica aqui
## porque o pedaco que nasce no meio da noite precisa acender o poste dele na
## hora, sem esperar a proxima virada.
static var editor_gerencia_pecas := false
static var luzes_acesas := false

## Pelo caminho e nao pelo nome global: o nome so existe depois que o editor
## varre o projeto, e isso quebra exportacao limpa.
const RELEVO := preload("res://scripts/relevo.gd")
static var _prop_material: Material = null
static var _material_com_vento: ShaderMaterial = null

## O TripoSR pinta o modelo em COR POR VERTICE, sem textura. Sem um material que
## leia essa cor como albedo, a arvore chega branca e o ambiente azul do ceu a
## deixa azulada. O material e um so para todo o mundo: alem de corrigir a cor,
## e uma troca de estado a menos por objeto desenhado.
static func prop_material() -> Material:
    if _prop_material == null:
        _prop_material = load("res://materials/triposr_props.tres")
    return _prop_material

## O material das coisas que tem folha.
##
## So a vegetacao recebe. Muro e casa balancando denuncia o truque na hora, e e
## o tipo de detalhe que o jogador nota sem saber dizer o que viu.
static func material_com_vento() -> ShaderMaterial:
    if _material_com_vento == null:
        _material_com_vento = ShaderMaterial.new()
        _material_com_vento.shader = load("res://materials/prop_vento.gdshader")
    return _material_com_vento

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
    var layout: Array = World.city_layout(String(region.get("id", "")))

    # As plaquinhas nao viram no na hora: acumulam aqui, por textura, e no fim
    # cada textura sai como UM objeto so com milhares de copias dentro.
    # Dentro da praca desenhada nada nasce por sorteio — nem arvore, nem mato.
    # A lista de etiquetas proibidas nao bastava: bastava alguem acrescentar uma
    # etiqueta nova em regions.json para voltar a chover objeto no meio da rua.
    # A regra por AREA nao tem esse buraco.
    var raio_reservado := CLEARING_RADIUS
    if not layout.is_empty():
        raio_reservado = RELEVO.raio_da_praca(World.cell_center(World.cell_at(center)))

    var lotes: Dictionary = {}
    for entry in region.get("props", []):
        # Tudo que define a leitura urbana vem da planta assinada, abaixo.
        # Vegetacao miuda ainda pode preencher o limite da celula, mas casa,
        # monumento, muro e mobiliario nunca mais sao sorteados.
        _scatter(root, entry, rng, center, lotes, raio_reservado)
    if not layout.is_empty() and not editor_gerencia_pecas:
        _montar_layout_urbano(root, layout, center)
    _montar_lotes(root, lotes)
    return root

## Constroi a parte autoral de uma cidade.
##
## As coordenadas sao locais ao centro da regiao. Isso deixa a planta legivel
## no JSON (a praca e 0,0) e permite que a mesma cidade atravesse varios chunks
## sem duplicar uma casa na divisa.
static func _montar_layout_urbano(root: Node3D, layout: Array, center: Vector3) -> void:
    var half := CHUNK_SIZE * 0.5
    var region_center := World.cell_center(World.cell_at(center))
    for item in layout:
        var tag := String(item.get("tag", ""))
        var kind: Dictionary = World.catalog.get(tag, {})
        if kind.is_empty():
            push_warning("Etiqueta urbana fora do catalogo: " + tag)
            continue

        var local: Array = item.get("position", [0.0, 0.0])
        var mundo := region_center + Vector3(float(local[0]), 0.0, float(local[1]))
        var offset := mundo - center
        # Um unico chunk e dono da peca, inclusive quando ela encosta na borda.
        if offset.x < -half or offset.x >= half or offset.z < -half or offset.z >= half:
            continue

        var rng := RandomNumberGenerator.new()
        rng.seed = hash([String(item.get("id", tag)), int(region_center.x), int(region_center.z)])
        var prop := _criar(kind, rng, String(item.get("model", "")))
        if prop == null:
            continue
        offset.y = RELEVO.altura(mundo.x, mundo.z) + float(item.get("y", 0.0))
        prop.position = offset
        var rot = item.get("rotation", 0.0)
        if typeof(rot) == TYPE_ARRAY:
            var rx: float = float(rot[0]) if rot.size() > 0 else 0.0
            var ry: float = float(rot[1]) if rot.size() > 1 else 0.0
            var rz: float = float(rot[2]) if rot.size() > 2 else 0.0
            prop.rotation = Vector3(deg_to_rad(rx), deg_to_rad(ry), deg_to_rad(rz))
        else:
            prop.rotation.y = deg_to_rad(float(rot))
        prop.scale = Vector3.ONE * float(item.get("scale", 1.0))
        prop.name = String(item.get("id", tag))
        root.add_child(prop)
        if bool(item.get("solid", kind.get("solid", false))):
            PropCollider.apply_to_asset(prop)

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
                     center: Vector3, lotes: Dictionary,
                     raio_reservado := CLEARING_RADIUS) -> void:
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

    # Construcao urbana sem planta nao recebe substituto aleatorio. Falhar
    # vazio e deliberado: um buraco visivel pede design; uma cidade sorteada
    # parece pronta e perpetua justamente o defeito que queremos eliminar.
    if bool(kind.get("na_vila", false)):
        return

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
            if (center + offset - region_center).length() < raio_reservado:
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

static func _criar(kind: Dictionary, rng: RandomNumberGenerator, model_path := "") -> Node3D:
    var models: Array = kind.get("models", [])
    var sprites: Array = kind.get("sprites", [])
    var caminho := model_path
    if caminho.is_empty():
        if not models.is_empty():
            caminho = String(models[rng.randi() % models.size()])
        elif not sprites.is_empty():
            caminho = String(sprites[rng.randi() % sprites.size()])
            
    if caminho.is_empty():
        return null

    var suporte := Node3D.new()

    if caminho.ends_with(".png"):
        var textura := _load_texture(caminho)
        if textura == null: return null
        
        var altura := float(kind.get("altura", 1.0))
        var proporcao := float(textura.get_width()) / float(textura.get_height())
        
        var quadro := QuadMesh.new()
        quadro.size = Vector2(altura * proporcao, altura)
        quadro.center_offset = Vector3(0.0, altura * 0.5, 0.0)
        quadro.material = _material_de_planta(textura)
        
        var modelo := MeshInstance3D.new()
        modelo.mesh = quadro
        modelo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        
        var tex_sombra := _load_texture("res://textures/sombra_contato.png")
        if tex_sombra:
            var sombra := _pose_da_sombra(Transform3D.IDENTITY, altura * proporcao)
            var mat_sombra := StandardMaterial3D.new()
            mat_sombra.albedo_texture = tex_sombra
            mat_sombra.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
            mat_sombra.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
            mat_sombra.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
            mat_sombra.cull_mode = BaseMaterial3D.CULL_DISABLED
            var quad_sombra := QuadMesh.new()
            quad_sombra.size = Vector2.ONE
            quad_sombra.material = mat_sombra
            var node_sombra := MeshInstance3D.new()
            node_sombra.mesh = quad_sombra
            node_sombra.transform = sombra
            node_sombra.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
            suporte.add_child(node_sombra)
            
        suporte.name = "Sprite2D"
        suporte.add_child(modelo)
    else:
        var scene := _load_scene(caminho)
        if scene == null: return null
        var modelo: Node3D = scene.instantiate()
        var is_custom := caminho.begins_with("user://") or bool(kind.get("is_custom", false)) or bool(kind.get("keep_materials", false))
        if not is_custom:
            var material: Material = material_com_vento() if bool(kind.get("vento", false)) else prop_material()
            for mesh_node in modelo.find_children("*", "MeshInstance3D", true, false):
                mesh_node.material_override = material
        else:
            if bool(kind.get("vento", false)):
                for mesh_node in modelo.find_children("*", "MeshInstance3D", true, false):
                    mesh_node.material_override = material_com_vento()
        suporte.name = modelo.name
        suporte.add_child(modelo)

        # A altura em METROS do catalogo manda, igual ao caminho das plaquinhas.
        #
        # O TripoSR devolve tudo normalizado a mais ou menos uma unidade, seja
        # casa ou barril. Sem esta conta, uma casa entrava no mundo com 1,25 m —
        # menor que o heroi, que tem 1,75 — e a cidade inteira virava maquete.
        # O 'scale' da planta urbana continua valendo por cima, como ajuste fino.
        var caixa := _caixa_do_modelo(modelo)
        var fator := 1.0
        var altura_alvo := float(kind.get("altura", 0.0))
        if altura_alvo > 0.0 and caixa.size.y > 0.0001:
            fator = altura_alvo / caixa.size.y
            modelo.scale = Vector3.ONE * fator
        # O deslocamento que apoia o pe no chao vale no espaco do SUPORTE, e nao
        # e afetado pela escala do modelo: tem de ser multiplicado a mao, senao o
        # objeto sobe ou afunda na exata proporcao em que foi redimensionado.
        modelo.position.y = -caixa.position.y * fator

    if bool(kind.get("luz", false)):
        suporte.add_child(_lampada())
        suporte.add_child(_claro_no_chao())
    return suporte

## A lampada no alto do poste.
##
## Alcance curto de proposito. Luz pontual e cara no renderizador de
## compatibilidade, que e o que roda no navegador, e o custo cresce com o volume
## que ela ilumina — nao com o brilho. Sete metros acendem a rua sem cobrar o
## preco de iluminar a vila inteira, e como ela nao projeta sombra, sao poucos
## objetos por poste.
## O circulo de luz que o poste joga no chao.
##
## Existe porque a luz pontual NAO aparece: o jogo roda no renderizador de
## compatibilidade — o unico que o navegador aceita — e la a OmniLight3D nao
## chega ao chao. Testado com energia 40 e alcance 30 metros: nenhuma diferenca
## na tela. A lampada continua no poste porque acende o proprio modelo de perto;
## quem desenha a poca de luz e esta mancha.
##
## Nao e gambiarra de segunda escolha: com a camera de cima, o que o jogador ve
## de um poste E o circulo no chao. Uma mancha aditiva custa um quadrado de dois
## triangulos, contra o preco de uma luz de verdade por objeto iluminado.
static func _claro_no_chao() -> MeshInstance3D:
    var quadro := QuadMesh.new()
    quadro.size = Vector2(5.4, 5.4)
    # Deitada e logo acima do chao: colada demais briga pelo mesmo pixel e pisca.
    quadro.orientation = PlaneMesh.FACE_Y
    quadro.center_offset = Vector3(0.0, 0.04, 0.0)

    var material := StandardMaterial3D.new()
    # Textura BRANCA, nao a da sombra. A da sombra e preta com alpha, e preto
    # somado ao que ja esta na tela nao acende nada — foi por isso que a primeira
    # versao da poca de luz nao apareceu.
    material.albedo_texture = _load_texture("res://textures/brilho_poste.png")
    # Fraca de proposito. A mistura e ADITIVA: dois postes perto somam, tres
    # estouram em branco. No brilho cheio a praca virava uma chapa clara — este
    # tom aguenta tres ou quatro sobrepostos sem lavar.
    material.albedo_color = Color(0.46, 0.33, 0.16)
    # Aditiva: luz SOMA ao que ja esta desenhado, nao cobre. Mistura normal
    # poria um disco laranja opaco sobre a grama, que le como tapete.
    material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    quadro.material = material

    var no := MeshInstance3D.new()
    no.name = "ClaroNoChao"
    no.mesh = quadro
    no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    no.visible = luzes_acesas
    no.add_to_group("claro_de_poste")
    return no

static func _lampada() -> OmniLight3D:
    var luz := OmniLight3D.new()
    luz.name = "Lampada"
    # Altura no modelo ja escalado: o poste tem uns 3 m e a luminaria fica no topo.
    luz.position = Vector3(0.0, 0.86, 0.0)
    luz.light_color = Color(1.0, 0.82, 0.52)
    luz.omni_range = 13.0
    luz.omni_attenuation = 0.9
    luz.shadow_enabled = false
    luz.light_energy = 6.5 if luzes_acesas else 0.0
    luz.visible = luzes_acesas
    luz.add_to_group("lampada")
    return luz

## Onde esta o ponto mais baixo da malha, no espaco do proprio modelo.
##
## Era uma altura fixa por etiqueta no catalogo — 1.7 m para o muro, 2.2 m para
## a arvore. Nao tinha como acertar: os GLB do TripoSR trazem o centro em lugar
## diferente cada um, e a escala ainda e sorteada numa faixa. Numero fixo contra
## escala sorteada da objeto enterrado ou flutuando, e foi o que deu.
static func _base_do_modelo(modelo: Node3D) -> float:
    return _caixa_do_modelo(modelo).position.y

## A caixa que envolve todas as malhas do modelo, no espaco do proprio modelo.
##
## Serve a duas perguntas que precisam da MESMA medida: onde esta o pe do objeto
## (para apoia-lo no chao) e qual a altura dele (para leva-lo ao tamanho que o
## catalogo declara). Medir duas vezes, em lugares diferentes, e como as duas
## acabariam discordando.
static func _caixa_do_modelo(modelo: Node3D) -> AABB:
    var caixa := AABB()
    var achou := false
    for malha in modelo.find_children("*", "MeshInstance3D", true, false):
        var local: AABB = _ate_a_raiz(malha, modelo) * malha.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    return caixa if achou else AABB()

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

static var _custom_scenes: Dictionary = {}

static func registrar_cena_custom(caminho: String, cena: PackedScene) -> void:
    _custom_scenes[caminho] = cena

static func _carregar_glb_bytes(bytes: PackedByteArray) -> PackedScene:
    var doc := GLTFDocument.new()
    var state := GLTFState.new()
    var err := doc.append_from_buffer(bytes, "", state)
    if err != OK:
        push_error("Falha ao processar buffer GLTF: %d" % err)
        return null
    var root_node := doc.generate_scene(state)
    if root_node == null:
        push_error("Falha ao gerar cena GLTF")
        return null
    var packed := PackedScene.new()
    packed.pack(root_node)
    return packed

static func _carregar_glb_de_arquivo(path: String) -> PackedScene:
    var f := FileAccess.open(path, FileAccess.READ)
    if f == null:
        return null
    var bytes := f.get_buffer(f.get_length())
    f.close()
    return _carregar_glb_bytes(bytes)

static func _load_scene(path: String) -> PackedScene:
    if _custom_scenes.has(path):
        return _custom_scenes[path]
    if path.begins_with("user://"):
        var packed := _carregar_glb_de_arquivo(path)
        if packed != null:
            _custom_scenes[path] = packed
            return packed
    if not _scene_cache.has(path):
        _scene_cache[path] = load(path) as PackedScene
    return _scene_cache.get(path)
