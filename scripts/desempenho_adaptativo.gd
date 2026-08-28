extends Node
## Reduz só a resolução interna do 3D quando um navegador não sustenta FPS.
## A interface continua nítida e a qualidade volta aos poucos quando há folga.

const INTERVALO := 1.5
const ESCALA_MINIMA := 0.50
const FPS_ALVO := 35

var _tempo := 0.0
var _baixos := 0
var _altos := 0
var _espera := 0.0
var _escala_maxima := 1.0


func _ready() -> void:
    _escala_maxima = get_viewport().scaling_3d_scale
    var web := OS.has_feature("web")
    if web:
        # 35 quadros estáveis são melhores que alternar entre 50 e 20. O teto
        # também deixa CPU/GPU respirarem para carregar uma zona vizinha.
        Engine.max_fps = FPS_ALVO
    set_process(web)


func _process(delta: float) -> void:
    _tempo += delta
    _espera = maxf(0.0, _espera - delta)
    if _tempo < INTERVALO:
        return
    _tempo = 0.0
    var fps := Engine.get_frames_per_second()
    _baixos = _baixos + 1 if fps > 0 and fps < 31 else 0
    _altos = _altos + 1 if fps >= 34 else 0
    if _espera > 0.0:
        return
    var viewport := get_viewport()
    if _baixos >= 2 and viewport.scaling_3d_scale > ESCALA_MINIMA:
        viewport.scaling_3d_scale = maxf(ESCALA_MINIMA, viewport.scaling_3d_scale - 0.10)
        _baixos = 0
        _altos = 0
        _espera = 4.0
    elif _altos >= 8 and viewport.scaling_3d_scale < _escala_maxima:
        viewport.scaling_3d_scale = minf(_escala_maxima, viewport.scaling_3d_scale + 0.03)
        _baixos = 0
        _altos = 0
        _espera = 12.0
