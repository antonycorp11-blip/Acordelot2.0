extends Node
## O MODO AUTOMÁTICO: mantém o quadro de pé trocando o nível gráfico sozinho.
##
## Antes ele mexia direto em `scaling_3d_scale`, por conta própria. Isso brigava
## com a tela de ajustes — o jogador escolhia Alto e, um minuto depois, estava
## rodando numa resolução que ninguém pediu e que a tela continuava jurando ser
## Alta. Agora existe um dono só para essa decisão: quem manda é o nível, e este
## nó apenas SUGERE um nível diferente quando o aparelho não está dando conta.
##
## Só age no modo automático. Escolha explícita do jogador é escolha: se ele
## selecionou Alto num aparelho que não aguenta, o certo é entregar Alto e deixar
## o medidor mostrar por que ficou pesado.

const INTERVALO := 1.5
## Abaixo disto o aparelho não está entregando o teto de 35 do navegador nem de
## longe, e vale descer um degrau.
const FPS_APERTADO := 27
## Quanto tempo seguido de folga antes de tentar subir. Alto de propósito: cair é
## barato, subir e cair de novo é o liga-desliga que dá enjoo.
const LEITURAS_PARA_SUBIR := 10
const LEITURAS_PARA_DESCER := 2

var _tempo := 0.0
var _baixos := 0
var _altos := 0
var _espera := 0.0
var _ajustes: Node = null


func _ready() -> void:
    if OS.has_feature("web"):
        # 35 quadros estáveis são melhores que alternar entre 50 e 20. O teto
        # também deixa CPU/GPU respirarem para carregar uma zona vizinha.
        Engine.max_fps = 35


func _process(delta: float) -> void:
    _tempo += delta
    _espera = maxf(0.0, _espera - delta)
    if _tempo < INTERVALO:
        return
    _tempo = 0.0
    if not Ajustes.automatico:
        _baixos = 0
        _altos = 0
        return

    var fps := Engine.get_frames_per_second()
    if fps <= 0:
        return
    # O alvo de subida acompanha o teto do navegador: com max_fps em 35, exigir
    # 50 para subir de nível deixaria o modo automático preso no Baixo para
    # sempre, mesmo num aparelho sobrando desempenho.
    var teto: float = float(Engine.max_fps) if Engine.max_fps > 0 else 60.0
    _baixos = _baixos + 1 if fps < FPS_APERTADO else 0
    _altos = _altos + 1 if float(fps) >= teto - 2.0 else 0
    if _espera > 0.0:
        return

    var tela := _tela_de_ajustes()
    if tela == null:
        return
    if _baixos >= LEITURAS_PARA_DESCER and Ajustes.nivel_atual > 0:
        tela.nivel_sugerido(Ajustes.nivel_atual - 1)
        _zerar(6.0)
    elif _altos >= LEITURAS_PARA_SUBIR and Ajustes.nivel_atual < Ajustes.NIVEIS.size() - 1:
        tela.nivel_sugerido(Ajustes.nivel_atual + 1)
        _zerar(14.0)


func _zerar(quanto: float) -> void:
    _baixos = 0
    _altos = 0
    _espera = quanto


func _tela_de_ajustes() -> Node:
    if _ajustes == null or not is_instance_valid(_ajustes):
        _ajustes = get_tree().root.find_child("Ajustes", true, false)
    return _ajustes
