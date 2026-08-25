extends Area3D

## Baú leve da primeira dungeon. Abre ao Akles se aproximar e entrega Claves.
const MALHA_COMUM := preload("res://assets/dungeon/quaternius/Chest.obj")
const MALHA_DOURADA := preload("res://assets/dungeon/quaternius/Chest_Gold.obj")

@export var recompensa_claves := 150
@export var dourado := false

var _aberto := false
var _visual: MeshInstance3D
var _rotulo: Label3D


func _ready() -> void:
    collision_layer = 0
    collision_mask = 1
    body_entered.connect(_ao_entrar)

    _visual = MeshInstance3D.new()
    _visual.mesh = MALHA_DOURADA if dourado else MALHA_COMUM
    _visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    _visual.visibility_range_end = 42.0
    # O OBJ traz cores lineares muito escuras no Compatibility. Uma paleta
    # explícita mantém madeira e ferragens legíveis na caverna e no navegador.
    for superficie in range(_visual.mesh.get_surface_count()):
        var mat := StandardMaterial3D.new()
        if superficie == 1:
            mat.albedo_color = Color(0.72, 0.42, 0.10) if dourado else Color(0.32, 0.36, 0.46)
            mat.metallic = 0.35
            mat.roughness = 0.38
            if dourado:
                mat.emission_enabled = true
                mat.emission = Color(0.55, 0.24, 0.03)
                mat.emission_energy_multiplier = 0.55
        else:
            mat.albedo_color = Color(0.30, 0.12, 0.055) if superficie == 0 else Color(0.48, 0.23, 0.08)
            mat.roughness = 0.88
        _visual.set_surface_override_material(superficie, mat)
    add_child(_visual)

    var forma := CollisionShape3D.new()
    var caixa := BoxShape3D.new()
    caixa.size = Vector3(1.5, 1.3, 1.3)
    forma.shape = caixa
    forma.position.y = 0.65
    add_child(forma)

    _rotulo = Label3D.new()
    _rotulo.text = "BAÚ DE TESOURO"
    _rotulo.position = Vector3(0.0, 1.55, 0.0)
    _rotulo.font_size = 28
    _rotulo.outline_size = 7
    _rotulo.modulate = Color(1.0, 0.83, 0.38)
    _rotulo.outline_modulate = Color(0.08, 0.04, 0.01, 0.95)
    _rotulo.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(_rotulo)

    # Sem uma luz dinâmica por baú: a emissão acima já destaca o tesouro e
    # custa menos em celulares simples.


func _ao_entrar(corpo: Node3D) -> void:
    if _aberto or not corpo.is_in_group("player"):
        return
    _aberto = true
    monitoring = false
    var progresso := get_node_or_null("/root/Progresso")
    if progresso and progresso.has_method("adicionar_recurso"):
        progresso.adicionar_recurso("claves", recompensa_claves)

    _rotulo.text = "+%d CLAVES" % recompensa_claves
    var tw := create_tween()
    tw.tween_property(_visual, "position:y", 0.28, 0.16).set_trans(Tween.TRANS_BACK)
    tw.tween_property(_visual, "position:y", 0.0, 0.18)
    tw.parallel().tween_property(_rotulo, "position:y", 2.25, 0.7)
    tw.parallel().tween_property(_rotulo, "modulate:a", 0.0, 0.7).set_delay(0.25)
