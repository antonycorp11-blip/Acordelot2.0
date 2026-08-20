extends CharacterBody3D
class_name Bicho

const MONSTROS_CONFIG := [
    {"nome": "Dragão Negro", "path": "res://models/black_dragon.glb", "altura": 3.2, "hp": 350.0, "cor": Color(0.85, 0.25, 0.25)},
    {"nome": "Golem Demoníaco", "path": "res://models/monster.glb", "altura": 2.2, "hp": 220.0, "cor": Color(0.9, 0.45, 0.15)},
    {"nome": "Monstro do Pântano", "path": "res://models/swamp_monster.glb", "altura": 2.4, "hp": 240.0, "cor": Color(0.3, 0.85, 0.4)},
    {"nome": "Orc Guerreiro", "path": "res://models/monster_orc.glb", "altura": 2.0, "hp": 180.0, "cor": Color(0.4, 0.65, 0.95)}
]

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

func _ready() -> void:
    add_to_group("bicho")
    _fase = randf() * TAU
    
    var cfg: Dictionary = MONSTROS_CONFIG[monster_type % MONSTROS_CONFIG.size()]
    vida_maxima = float(cfg.get("hp", 200.0))
    vida = vida_maxima
    
    var forma := CollisionShape3D.new()
    var capsula := CapsuleShape3D.new()
    capsula.radius = 0.75
    capsula.height = float(cfg.get("altura", 2.2))
    forma.shape = capsula
    forma.position.y = capsula.height * 0.5
    add_child(forma)
    
    _construir_modelo(cfg)
    _construir_barra_vida_3d(cfg)

func _construir_modelo(cfg: Dictionary) -> void:
    var path: String = str(cfg["path"])
    if not ResourceLoader.exists(path):
        return
        
    var scene := load(path) as PackedScene
    if not scene:
        return
        
    _modelo = scene.instantiate()
    add_child(_modelo)

    var mat_triposr := preload("res://materials/triposr_props.tres")
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        var m_inst := malha as MeshInstance3D
        if m_inst and m_inst.mesh:
            var precisa_override := false
            for s in range(m_inst.mesh.get_surface_count()):
                var mat: Material = m_inst.get_active_material(s)
                var fmt: int = m_inst.mesh.surface_get_format(s)
                var has_vc: bool = (fmt & Mesh.ARRAY_FORMAT_COLOR) != 0
                var has_tex: bool = false
                if mat is StandardMaterial3D:
                    var sm := mat as StandardMaterial3D
                    has_tex = (sm.albedo_texture != null)
                if has_vc and not has_tex:
                    precisa_override = true
                    break
            if precisa_override:
                m_inst.material_override = mat_triposr
    
    # Toca animação de idle se existir no modelo (ex: black dragon)
    _anim_player = _modelo.find_child("AnimationPlayer", true, false) as AnimationPlayer
    if _anim_player:
        var anim_list := _anim_player.get_animation_list()
        if not anim_list.is_empty():
            _anim_player.play(anim_list[0])
    
    # Mede AABB no espaço do modelo e assenta no chão
    var caixa := AABB()
    var achou := false
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        var local: AABB = _ate_a_raiz(malha as Node3D, _modelo) * (malha as MeshInstance3D).get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
        
    var altura_alvo: float = float(cfg.get("altura", 2.2))
    var fator := 1.0
    if altura_alvo > 0.0 and caixa.size.y > 0.05:
        fator = clampf(altura_alvo / caixa.size.y, 0.05, 3.5)
    else:
        fator = 1.0
        
    _modelo.scale = Vector3.ONE * fator
    _modelo.position.y = -caixa.position.y * fator

func _ate_a_raiz(no: Node3D, raiz: Node3D) -> Transform3D:
    var acumulado := Transform3D.IDENTITY
    var atual: Node3D = no
    while atual != null and atual != raiz:
        acumulado = atual.transform * acumulado
        atual = atual.get_parent() as Node3D
    return acumulado

func _construir_barra_vida_3d(cfg: Dictionary) -> void:
    var h: float = float(cfg.get("altura", 2.2)) + 0.6
    
    _name_label_3d = Label3D.new()
    _name_label_3d.text = str(cfg.get("nome", "Monstro"))
    _name_label_3d.font_size = 22
    _name_label_3d.outline_size = 5
    _name_label_3d.modulate = Color(1.0, 0.9, 0.5)
    _name_label_3d.outline_modulate = Color(0.1, 0.05, 0.02, 0.95)
    _name_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _name_label_3d.position = Vector3(0.0, h + 0.45, 0.0)
    add_child(_name_label_3d)
    
    _hp_label_3d = Label3D.new()
    _hp_label_3d.text = "❤️ %d / %d" % [int(vida), int(vida_maxima)]
    _hp_label_3d.font_size = 19
    _hp_label_3d.outline_size = 4
    _hp_label_3d.modulate = Color(0.95, 0.3, 0.3)
    _hp_label_3d.outline_modulate = Color(0.15, 0.0, 0.0, 0.95)
    _hp_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _hp_label_3d.position = Vector3(0.0, h, 0.0)
    add_child(_hp_label_3d)

func _physics_process(delta: float) -> void:
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
    
    if alvo and is_instance_valid(alvo):
        var ate := alvo.global_position - global_position
        ate.y = 0.0
        var dist := ate.length()
        
        # Persegue o jogador sem causar dano
        if dist < RAIO_DE_ATENCAO and dist > DISTANCIA_DE_PARADA:
            desejada = ate.normalized() * VELOCIDADE
            var target_angle := atan2(ate.x, ate.z)
            rotation.y = lerp_angle(rotation.y, target_angle, 8.0 * delta)
        elif dist <= DISTANCIA_DE_PARADA:
            var target_angle := atan2(ate.x, ate.z)
            rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)
            
    velocity.x = move_toward(velocity.x, desejada.x, 14.0 * delta)
    velocity.z = move_toward(velocity.z, desejada.z, 14.0 * delta)
    move_and_slide()

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
        _hp_label_3d.text = "❤️ %d / %d" % [int(vida), int(vida_maxima)]
        
    _criar_popup_dano(quantidade)
    
    var empurrao := direcao
    empurrao.y = 0.0
    velocity += empurrao.normalized() * EMPURRAO
    _atordoado_ate = Time.get_ticks_msec() / 1000.0 + ATORDOAMENTO
    
    _piscar_dano()
    
    if vida <= 0.0:
        _morrer()

func _piscar_dano() -> void:
    if not _modelo:
        return
    var tw := create_tween()
    tw.tween_property(_modelo, "position:y", _modelo.position.y + 0.15, 0.08)
    tw.tween_property(_modelo, "position:y", _modelo.position.y, 0.08)

func _criar_popup_dano(qtd: float) -> void:
    var lbl := Label3D.new()
    lbl.text = "-%d" % int(qtd)
    lbl.font_size = 28
    lbl.outline_size = 6
    lbl.modulate = Color(1.0, 0.85, 0.2)
    lbl.outline_modulate = Color(0.8, 0.1, 0.1, 1.0)
    lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    lbl.position = Vector3(randf_range(-0.3, 0.3), 3.2, randf_range(-0.3, 0.3))
    add_child(lbl)
    
    var tw := create_tween()
    tw.tween_property(lbl, "position:y", lbl.position.y + 1.3, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
    tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
    tw.tween_callback(lbl.queue_free)

func _morrer() -> void:
    remove_from_group("bicho")
    if _hp_label_3d: _hp_label_3d.visible = false
    if _name_label_3d: _name_label_3d.visible = false
    
    var tw := create_tween()
    tw.tween_property(_modelo, "scale", Vector3.ZERO, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
    tw.parallel().tween_property(_modelo, "position:y", _modelo.position.y + 0.8, 0.45)
    tw.tween_callback(queue_free)
