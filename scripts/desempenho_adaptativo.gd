extends Node
## Reduz só a resolução interna do 3D quando um navegador não sustenta FPS.
## A interface continua nítida e a qualidade volta aos poucos quando há folga.

const INTERVALO := 2.0
const ESCALA_MINIMA := 0.50

var _tempo := 0.0
var _baixos := 0
var _altos := 0
var _espera := 0.0
var _escala_maxima := 1.0


func _ready() -> void:
    _escala_maxima = get_viewport().scaling_3d_scale
    set_process(OS.has_feature("web"))


func _process(delta: float) -> void:
    _tempo += delta
    _espera = maxf(0.0, _espera - delta)
    if _tempo < INTERVALO:
        return
    _tempo = 0.0
    var fps := Engine.get_frames_per_second()
    _baixos = _baixos + 1 if fps > 0 and fps < 27 else 0
    _altos = _altos + 1 if fps > 47 else 0
    if _espera > 0.0:
        return
    var viewport := get_viewport()
    if _baixos >= 3 and viewport.scaling_3d_scale > ESCALA_MINIMA:
        viewport.scaling_3d_scale = maxf(ESCALA_MINIMA, viewport.scaling_3d_scale - 0.08)
        _baixos = 0
        _altos = 0
        _espera = 8.0
    elif _altos >= 6 and viewport.scaling_3d_scale < _escala_maxima:
        viewport.scaling_3d_scale = minf(_escala_maxima, viewport.scaling_3d_scale + 0.04)
        _baixos = 0
        _altos = 0
        _espera = 10.0
