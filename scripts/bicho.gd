extends CharacterBody3D
class_name Bicho

const MONSTROS_CONFIG := [
    {"nome": "Golem da Floresta", "path": "res://models/media_1787068821885.glb", "altura": 2.2, "hp": 180.0, "cor": Color(0.9, 0.4, 0.2)},
    {"nome": "Besta Voraz", "path": "res://models/media_1787068825917.glb", "altura": 1.8, "hp": 140.0, "cor": Color(0.3, 0.85, 0.4)},
    {"nome": "Lobo Espectral", "path": "res://models/media_1787068829583.glb", "altura": 1.7, "hp": 120.0, "cor": Color(0.4, 0.6, 0.95)},
    {"nome": "Guardião Abissal", "path": "res://models/media_1787068833589.glb", "altura": 2.5, "hp": 220.0, "cor": Color(0.85, 0.3, 0.85)}
]

@export var monster_type: int = 0

var vida_maxima: float = 150.0
var vida: float = 150.0

const VELOCIDADE := 3.2
const RAIO_DE_ATENCAO := 15.0
const DISTANCIA_DE_PARADA := 1.9
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
var _spawn_pos: Vector3

func _ready() -> void:
    add_to_group("bicho")
    _spawn_pos = global_position
    _fase = randf() * TAU
    
    var cfg: Dictionary = MONSTROS_CONFIG[monster_type % MONSTROS_CONFIG.size()]
    vida_maxima = float(cfg.get("hp", 150.0))
    vida = vida_maxima
    
    var forma := CollisionShape3D.new()
    var capsula := CapsuleShape3D.new()
    capsula.radius = 0.65
    capsula.height = float(cfg.get("altura", 2.0))
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
    
    # Mede AABB e assenta no chão
    var caixa := AABB()
    var achou := false
    for malha in _modelo.find_children("*", "MeshInstance3D", true, false):
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(1.0, 1.0, 1.0)
        mat.vertex_color_use_as_albedo = true
        mat.roughness = 0.85
        malha.material_override = mat
        _materials.append(mat)
        
        var local: AABB = (malha as MeshInstance3D).get_aabb()
        caixa = local if not achou else caixa.merge(local)
        achou = true
        
    var altura_alvo: float = float(cfg.get("altura", 2.0))
    var fator := 1.0
    if altura_alvo > 0.0 and caixa.size.y > 0.0001:
        fator = altura_alvo / caixa.size.y
        _modelo.scale = Vector3.ONE * fator
        
    _modelo.position.y = -caixa.position.y * fator

func _construir_barra_vida_3d(cfg: Dictionary) -> void:
    var h: float = float(cfg.get("altura", 2.0)) + 0.5
    
    _name_label_3d = Label3D.new()
    _name_label_3d.text = str(cfg.get("nome", "Monstro"))
    _name_label_3d.font_size = 20
    _name_label_3d.outline_size = 5
    _name_label_3d.modulate = Color(1.0, 0.9, 0.6)
    _name_label_3d.outline_modulate = Color(0.1, 0.05, 0.02, 0.9)
    _name_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    _name_label_3d.position = Vector3(0.0, h + 0.4, 0.0)
    add_child(_name_label_3d)
    
    _hp_label_3d = Label3D.new()
    _hp_label_3d.text = "❤️ %d / %d" % [int(vida), int(vida_maxima)]
    _hp_label_3d.font_size = 18
    _hp_label_3d.outline_size = 4
    _hp_label_3d.modulate = Color(0.95, 0.3, 0.3)
    _hp_label_3d.outline_modulate = Color(0.1, 0.0, 0.0, 0.9)
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
            # Encara o jogador em pose de combate
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
    for mat in _materials:
        mat.emission_enabled = true
        mat.emission = Color(1.0, 0.25, 0.25)
        mat.emission_energy_multiplier = 3.5
        
    var tw := create_tween()
    tw.tween_interval(0.15)
    tw.tween_callback(func():
        for mat in _materials:
            mat.emission_enabled = false
    )

func _criar_popup_dano(qtd: float) -> void:
    var lbl := Label3D.new()
    lbl.text = "-%d" % int(qtd)
    lbl.font_size = 28
    lbl.outline_size = 6
    lbl.modulate = Color(1.0, 0.85, 0.2)
    lbl.outline_modulate = Color(0.8, 0.1, 0.1, 1.0)
    lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    lbl.position = Vector3(randf_range(-0.3, 0.3), 2.8, randf_range(-0.3, 0.3))
    add_child(lbl)
    
    var tw := create_tween()
    tw.tween_property(lbl, "position:y", lbl.position.y + 1.2, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
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
