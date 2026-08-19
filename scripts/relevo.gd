class_name Relevo
extends RefCounted
## A altura do terreno em qualquer ponto do mundo.
##
## Uma funcao pura de (x, z), sem mapa guardado. O mundo tem 110 regioes de 120
## metros: um mapa de altura com resolucao util para 1,6 milhao de metros
## quadrados nao caberia na memoria do alvo, e ainda teria de ser baixado. Aqui
## a altura se calcula onde e quando precisa, e pedacos vizinhos casam na divisa
## sozinhos porque ambos perguntam o mesmo para a mesma coordenada.
##
## Quem pergunta: a malha do chao (por vertice), a colisao (por amostra), o
## capim (para nao nascer enterrado) e o gerador de bichos. Se algum deles
## calculasse por conta propria, o mato flutuaria sobre a encosta.

## Colinas largas. 2,6 m de desnivel a cada ~70 m e o que da encosta visivel da
## altura da camera sem virar montanha que esconde o jogador.
const ALTURA_DAS_COLINAS := 6.0
const TAMANHO_DAS_COLINAS := 48.0

## Ondulacao curta por cima, para a encosta nao ser uma rampa lisa.
const ALTURA_DO_RELEVO := 1.0
const TAMANHO_DO_RELEVO := 15.0

static var _colinas: FastNoiseLite
static var _detalhe: FastNoiseLite

static func _preparar() -> void:
    if _colinas != null:
        return
    _colinas = FastNoiseLite.new()
    _colinas.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _colinas.frequency = 1.0 / TAMANHO_DAS_COLINAS
    _colinas.seed = 20260819

    _detalhe = FastNoiseLite.new()
    _detalhe.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
    _detalhe.frequency = 1.0 / TAMANHO_DO_RELEVO
    _detalhe.seed = 991

static func altura(x: float, z: float) -> float:
    _preparar()
    return (_colinas.get_noise_2d(x, z) * ALTURA_DAS_COLINAS
        + _detalhe.get_noise_2d(x, z) * ALTURA_DO_RELEVO)

## Normal aproximada do terreno, por diferenca finita.
##
## Serve para deitar objeto na encosta em vez de deixa-lo em pe como poste. Um
## passo de meio metro e mais estavel que um infinitesimal: pega a inclinacao da
## ladeira e ignora a rugosidade fina, que so faria o objeto tremer.
static func normal(x: float, z: float) -> Vector3:
    const PASSO := 0.5
    var dx := altura(x + PASSO, z) - altura(x - PASSO, z)
    var dz := altura(x, z + PASSO) - altura(x, z - PASSO)
    return Vector3(-dx, 2.0 * PASSO, -dz).normalized()
