extends Node3D
class_name Wins

## Wins, cantora de combate. O corpo fisico continua sendo Player; este no
## cuida apenas da aparencia, animacoes, arma e habilidades da personagem.

const MODELO := preload("res://personagem/wins_base.fbx")
const ANIMACOES := preload("res://personagem/wins_anims.res")
const ARMA := preload("res://models/wins_arma.glb")

const ALTURA_ALVO := 1.70
const MISTURA := 0.16
const VELOCIDADE_DO_GOLPE := 1.75
const COMBO := ["ataque_1", "ataque_2", "ataque_3"]

var _animador: AnimationPlayer
var _modelo: Node3D
var _arma: Node3D
var _atacando := false
var _golpe := 0
var _golpe_pedido := false
var _fx: Node3D
var _anel: MeshInstance3D
var _aneis_secundarios: Array[MeshInstance3D] = []
var _material_onda: StandardMaterial3D
var _coro_fx: MultiMeshInstance3D
var _material_coro: StandardMaterial3D
var _feixe_fx: Node3D
var _material_feixe: StandardMaterial3D
var _tween_fx: Tween
var _tween_coro: Tween
var _tween_feixe: Tween

func _ready() -> void:
    _modelo = MODELO.instantiate()
    add_child(_modelo)
    _animador = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if _animador:
        _animador.add_animation_library("wins", ANIMACOES)
        _animador.animation_finished.connect(_ao_terminar_animacao)
    _normalizar_modelo()
    _equipar_arma()
    _preparar_fx()
    if _animador:
        _animador.play("wins/parado")

func _normalizar_modelo() -> void:
    var caixa := AABB()
    var achou := false
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        var local := _ate_a_raiz(mi, _modelo) * mi.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    if not achou or caixa.size.y < 0.05:
        return
    var fator := ALTURA_ALVO / caixa.size.y
    _modelo.scale = Vector3.ONE * fator
    _modelo.position.y = -caixa.position.y * fator

func _ate_a_raiz(no: Node3D, raiz: Node3D) -> Transform3D:
    var t := Transform3D.IDENTITY
    var atual: Node = no
    while atual and atual != raiz:
        if atual is Node3D:
            t = (atual as Node3D).transform * t
        atual = atual.get_parent()
    return t

func _equipar_arma() -> void:
    var esqueleto := _modelo.find_child("Skeleton3D", true, false) as Skeleton3D
    if esqueleto == null:
        return
    var indice := esqueleto.find_bone("mixamorig_RightHand")
    if indice < 0:
        return
    var suporte := BoneAttachment3D.new()
    suporte.bone_idx = indice
    esqueleto.add_child(suporte)
    var punho := Node3D.new()
    punho.name = "PunhoDaLanca"
    suporte.add_child(punho)
    _arma = ARMA.instantiate()
    punho.add_child(_arma)
    _dimensionar_arma()
    # O eixo longo do GLB e +Y (medido: 0,98 m contra 0,35 x 0,26). O giro de
    # 92 graus o deitava atraves da palma. O mesmo encaixe Mixamo usado pela
    # espada de Akles mantem o cabo acompanhando o osso da mao.
    punho.rotation_degrees = Vector3(180.0, 0.0, 0.0)
    _arma.position = Vector3(0.0, -0.10 / maxf(_modelo.scale.x, 0.001), 0.0)
    _arma.visible = false

func _dimensionar_arma() -> void:
    var caixa := AABB()
    var achou := false
    for malha in _arma.find_children("*", "MeshInstance3D", true, false):
        var mi := malha as MeshInstance3D
        var local := _ate_a_raiz(mi, _arma) * mi.get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
    if not achou:
        return
    var maior := maxf(caixa.size.x, maxf(caixa.size.y, caixa.size.z))
    if maior > 0.01:
        _arma.scale = Vector3.ONE * (1.65 / maior) / maxf(_modelo.scale.x, 0.001)

func _preparar_fx() -> void:
    _fx = Node3D.new()
    _fx.name = "VozFX"
    _fx.visible = false
    add_child(_fx)
    _anel = MeshInstance3D.new()
    var torus := TorusMesh.new()
    torus.inner_radius = 0.82
    torus.outer_radius = 1.0
    torus.rings = 16
    torus.ring_segments = 6
    _anel.mesh = torus
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.albedo_color = Color(0.42, 0.80, 1.0, 0.84)
    mat.emission_enabled = true
    mat.emission = Color(0.18, 0.55, 1.0)
    mat.emission_energy_multiplier = 2.0
    mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    _anel.material_override = mat
    _material_onda = mat
    _anel.position.y = 0.05
    _anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _fx.add_child(_anel)

    # Ecos concentricos tornam o pulso uma onda de VOZ, nao apenas um aro.
    for i in 2:
        var eco := MeshInstance3D.new()
        eco.mesh = torus.duplicate()
        eco.material_override = mat
        eco.position.y = 0.10 + i * 0.18
        eco.scale = Vector3.ONE * (0.72 - i * 0.16)
        eco.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _fx.add_child(eco)
        _aneis_secundarios.append(eco)

    _preparar_coro_prisional()
    _preparar_feixe_vocal()

func _preparar_coro_prisional() -> void:
    var barra := BoxMesh.new()
    barra.size = Vector3(0.16, 2.8, 0.16)
    _material_coro = StandardMaterial3D.new()
    _material_coro.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material_coro.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _material_coro.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    _material_coro.albedo_color = Color(0.72, 0.28, 1.0, 0.0)
    _material_coro.emission_enabled = true
    _material_coro.emission = Color(0.62, 0.18, 1.0)
    _material_coro.emission_energy_multiplier = 2.6
    barra.material = _material_coro
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = barra
    multi.instance_count = 12
    for i in multi.instance_count:
        var ang := TAU * float(i) / float(multi.instance_count)
        var p := Vector3(cos(ang) * 7.0, 1.4, sin(ang) * 7.0)
        multi.set_instance_transform(i, Transform3D(Basis(Vector3.UP, -ang), p))
    _coro_fx = MultiMeshInstance3D.new()
    _coro_fx.name = "CoroPrisionalFX"
    _coro_fx.multimesh = multi
    _coro_fx.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _coro_fx.visible = false
    add_child(_coro_fx)

func _preparar_feixe_vocal() -> void:
    _feixe_fx = Node3D.new()
    _feixe_fx.name = "ClimaxDaVozFX"
    _feixe_fx.top_level = true
    _feixe_fx.visible = false
    add_child(_feixe_fx)
    _material_feixe = StandardMaterial3D.new()
    _material_feixe.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    _material_feixe.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    _material_feixe.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
    _material_feixe.albedo_color = Color(1.0, 0.34, 0.82, 0.0)
    _material_feixe.emission_enabled = true
    _material_feixe.emission = Color(0.86, 0.22, 1.0)
    _material_feixe.emission_energy_multiplier = 2.8
    for i in 3:
        var faixa := MeshInstance3D.new()
        var caixa := BoxMesh.new()
        caixa.size = Vector3(1.1 + i * 0.65, 0.11, 15.5 - i * 1.4)
        caixa.material = _material_feixe
        faixa.mesh = caixa
        faixa.position = Vector3(0.0, (i - 1) * 0.22, -7.2 + i * 0.55)
        faixa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        _feixe_fx.add_child(faixa)

func atacando() -> bool:
    return _atacando

func atualizar_movimento(velocidade: float, voando := false) -> void:
    if _atacando or _animador == null:
        return
    var desejada := "wins/parado"
    if voando:
        desejada = "wins/voo"
    elif velocidade > 4.2:
        desejada = "wins/correr"
    elif velocidade > 0.2:
        desejada = "wins/andar"
    if _animador.current_animation != desejada:
        _animador.play(desejada, MISTURA)

func atacar() -> void:
    if _atacando:
        _golpe_pedido = true
        return
    _atacando = true
    if _arma:
        _arma.visible = true
    var nome: String = COMBO[_golpe]
    _golpe = (_golpe + 1) % COMBO.size()
    _animador.play("wins/" + nome, MISTURA, VELOCIDADE_DO_GOLPE)
    _impactar_depois(0.30, 1.0, 3.0, 130.0)

func _impactar_depois(parte: float, multiplicador: float, alcance: float, abertura: float) -> void:
    var duracao := _animador.current_animation_length / VELOCIDADE_DO_GOLPE
    await get_tree().create_timer(duracao * parte).timeout
    if _atacando:
        _atingir_cone(multiplicador, alcance, abertura, 0.25)

func _ao_terminar_animacao(nome: StringName) -> void:
    var curta := String(nome).trim_prefix("wins/")
    if not curta in COMBO and curta != "canto":
        return
    _atacando = false
    if _arma:
        _arma.visible = false
    if _golpe_pedido:
        _golpe_pedido = false
        atacar()
        return
    _animador.play("wins/parado", MISTURA)

## Skill 1 — Pulso de Comando: onda curta que interrompe o grupo ao redor.
func ativar_aura_azul() -> void:
    if _atacando:
        return
    _cantar()
    _mostrar_onda(6.0, Color(0.25, 0.78, 1.0))
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if is_instance_valid(bicho) and global_position.distance_to(bicho.global_position) <= 6.0:
            var afastar: Vector3 = (bicho.global_position - global_position).normalized()
            bicho.levar_dano(_dano_atual() * 0.80, afastar)
            if bicho.has_method("aplicar_controle"):
                bicho.aplicar_controle(1.55, afastar, 2.0)

## Skill 2 — Coro Prisional: puxa inimigos proximos para o centro e silencia.
func ativar_espada_gigante() -> void:
    if _atacando:
        return
    _cantar()
    _mostrar_onda(7.4, Color(0.72, 0.34, 1.0))
    _mostrar_coro()
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if not is_instance_valid(bicho):
            continue
        var ate: Vector3 = bicho.global_position - global_position
        ate.y = 0.0
        if ate.length() <= 7.4:
            bicho.levar_dano(_dano_atual(), Vector3.ZERO)
            if bicho.has_method("aplicar_controle"):
                bicho.aplicar_controle(2.4, -ate.normalized(), 5.5)

## Skill 3 — Climax da Voz: rajada direcionada, dano e forte afastamento.
func lancar_raio_kamehameha(direcao := Vector3.ZERO) -> void:
    if _atacando:
        return
    _cantar()
    var frente := direcao.normalized() if direcao.length_squared() > 0.01 else global_basis.z.normalized()
    _atingir_cone(2.0, 16.0, 82.0, 1.25, frente, 10.0)
    _mostrar_climax(frente)

func _cantar() -> void:
    _atacando = true
    if _animador:
        _animador.play("wins/canto", MISTURA, 2.10)

func _mostrar_onda(raio: float, cor: Color) -> void:
    if _tween_fx and _tween_fx.is_valid():
        _tween_fx.kill()
    _fx.visible = true
    _fx.scale = Vector3(0.3, 1.0, 0.3)
    _material_onda.albedo_color = Color(cor, 0.84)
    _material_onda.emission = cor
    _tween_fx = create_tween()
    _tween_fx.set_parallel(true)
    _tween_fx.tween_property(_fx, "scale", Vector3(raio, 1.0, raio), 0.42).set_trans(Tween.TRANS_QUAD)
    _tween_fx.tween_property(_material_onda, "albedo_color", Color(cor, 0.0), 0.42)
    _tween_fx.chain().tween_callback(func():
        _fx.visible = false
        _material_onda.albedo_color.a = 0.84)

func _mostrar_coro() -> void:
    if _tween_coro and _tween_coro.is_valid():
        _tween_coro.kill()
    _coro_fx.visible = true
    _material_coro.albedo_color = Color(0.72, 0.28, 1.0, 0.82)
    _coro_fx.scale = Vector3(0.72, 0.25, 0.72)
    _tween_coro = create_tween()
    _tween_coro.set_parallel(true)
    _tween_coro.tween_property(_coro_fx, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK)
    _tween_coro.tween_property(_material_coro, "albedo_color", Color(0.72, 0.28, 1.0, 0.0), 0.72).set_delay(0.28)
    _tween_coro.chain().tween_callback(func(): _coro_fx.visible = false)

func _mostrar_climax(frente: Vector3) -> void:
    if _tween_feixe and _tween_feixe.is_valid():
        _tween_feixe.kill()
    _feixe_fx.visible = true
    _feixe_fx.global_position = global_position + Vector3.UP * 0.85
    _feixe_fx.look_at(_feixe_fx.global_position + frente, Vector3.UP)
    _feixe_fx.scale = Vector3(0.15, 1.0, 0.06)
    _material_feixe.albedo_color = Color(1.0, 0.34, 0.82, 0.92)
    _tween_feixe = create_tween()
    _tween_feixe.set_parallel(true)
    _tween_feixe.tween_property(_feixe_fx, "scale", Vector3.ONE, 0.20).set_trans(Tween.TRANS_QUAD)
    _tween_feixe.tween_property(_material_feixe, "albedo_color", Color(0.55, 0.22, 1.0, 0.0), 0.52).set_delay(0.18)
    _tween_feixe.chain().tween_callback(func(): _feixe_fx.visible = false)

func _atingir_cone(mult: float, alcance: float, abertura: float, controle: float,
        direcao := Vector3.ZERO, empurrao := 0.0) -> void:
    var frente := direcao.normalized() if direcao.length_squared() > 0.01 else global_basis.z.normalized()
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if not is_instance_valid(bicho):
            continue
        var ate: Vector3 = bicho.global_position - global_position
        ate.y = 0.0
        if ate.length() < 0.05 or ate.length() > alcance:
            continue
        if frente.angle_to(ate.normalized()) > deg_to_rad(abertura * 0.5):
            continue
        bicho.levar_dano(_dano_atual() * mult, ate.normalized())
        if controle > 0.0 and bicho.has_method("aplicar_controle"):
            bicho.aplicar_controle(controle, ate.normalized(), empurrao)

func _dano_atual() -> float:
    var progresso := get_node_or_null("/root/Progresso")
    return float(progresso.estatisticas().get("ataque", 34.0)) if progresso else 34.0

func mostrar_mira_laser(_direcao: Vector3) -> void:
    pass

func esconder_mira_laser() -> void:
    pass
