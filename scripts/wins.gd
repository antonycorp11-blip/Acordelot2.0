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
var _tween_fx: Tween

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
    _arma = ARMA.instantiate()
    suporte.add_child(_arma)
    _dimensionar_arma()
    # O modelo combina lanca e lamina; acompanha o antebraco da animacao.
    _arma.rotation_degrees = Vector3(92.0, 4.0, -8.0)
    _arma.position = Vector3(0.0, -0.34, 0.02)
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
    _anel.material_override = mat
    _anel.position.y = 0.12
    _anel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _fx.add_child(_anel)

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
    _mostrar_onda(5.5, Color(0.25, 0.78, 1.0))
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if is_instance_valid(bicho) and global_position.distance_to(bicho.global_position) <= 5.5:
            bicho.levar_dano(_dano_atual() * 0.65, (bicho.global_position - global_position).normalized())
            if bicho.has_method("aplicar_controle"):
                bicho.aplicar_controle(1.35, Vector3.ZERO, 0.0)

## Skill 2 — Coro Prisional: puxa inimigos proximos para o centro e silencia.
func ativar_espada_gigante() -> void:
    if _atacando:
        return
    _cantar()
    _mostrar_onda(7.0, Color(0.72, 0.34, 1.0))
    for bicho in get_tree().get_nodes_in_group("bicho"):
        if not is_instance_valid(bicho):
            continue
        var ate: Vector3 = bicho.global_position - global_position
        ate.y = 0.0
        if ate.length() <= 7.0:
            bicho.levar_dano(_dano_atual() * 0.85, Vector3.ZERO)
            if bicho.has_method("aplicar_controle"):
                bicho.aplicar_controle(2.1, -ate.normalized(), 4.2)

## Skill 3 — Climax da Voz: rajada direcionada, dano e forte afastamento.
func lancar_raio_kamehameha(direcao := Vector3.ZERO) -> void:
    if _atacando:
        return
    _cantar()
    var frente := direcao.normalized() if direcao.length_squared() > 0.01 else global_basis.z.normalized()
    _atingir_cone(1.75, 14.0, 75.0, 1.0, frente, 8.0)
    _mostrar_onda(9.0, Color(1.0, 0.48, 0.82))

func _cantar() -> void:
    _atacando = true
    if _animador:
        _animador.play("wins/canto", MISTURA, 1.45)

func _mostrar_onda(raio: float, cor: Color) -> void:
    if _tween_fx and _tween_fx.is_valid():
        _tween_fx.kill()
    _fx.visible = true
    _fx.scale = Vector3.ONE * 0.3
    var mat := _anel.material_override as StandardMaterial3D
    mat.albedo_color = Color(cor, 0.84)
    mat.emission = cor
    _tween_fx = create_tween()
    _tween_fx.set_parallel(true)
    _tween_fx.tween_property(_fx, "scale", Vector3.ONE * raio, 0.38)
    _tween_fx.tween_property(mat, "albedo_color:a", 0.0, 0.38)
    _tween_fx.chain().tween_callback(func():
        _fx.visible = false
        mat.albedo_color.a = 0.84)

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
