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

## Onde a agua para. O relevo varia de uns -7 a +7 m; a -2,2 m os fundos de vale
## enchem e viram lagoa, e o resto do terreno fica seco. Nao ha mapa de lagos: o
## vale ja existe no relevo, e a agua so preenche o que estava baixo — que e como
## lagoa se forma no mundo real.
const NIVEL_DA_AGUA := -2.2

## Raio de reserva, usado so quando a planta urbana nao declara o seu, e a rampa
## que liga o plato ao morro em volta.
## Casa em ladeira nao existe: ou o terreno e nivelado, ou a construcao fica com
## metade enterrada e metade no ar — que e o que estava acontecendo.
const RAIO_DA_VILA := 30.0
const RAMPA_DA_VILA := 16.0

## Quanto a estrada fica acima da agua. Trilha que atravessa lagoa nao existe no
## mundo real: ou ha ponte, ou o caminho contorna. Levantar o leito da estrada
## resolve sem precisar decidir por onde ela passa.
const FOLGA_DA_ESTRADA := 0.9

static var _colinas: FastNoiseLite
static var _detalhe: FastNoiseLite
## Centro e raio do plato de cada vila. O raio vem da planta urbana, nao de uma
## constante: a peca mais distante de Portoes Reais esta a 40 m e a de uma aldeia
## a 16 — um raio unico ou deixaria a muralha na ladeira ou achataria meio mapa
## em volta de um vilarejo.
static var _vilas: Array[Vector2] = []
static var _raios: Array[float] = []
## Geometria viaria por cidade: x = avenidas, yzw = raio de cada anel.
static var _malhas: Array[Vector4] = []
static var _estradas: Image = null
static var _mundo_min := Vector2(-660.0, -540.0)
static var _mundo_tam := Vector2(1320.0, 1200.0)

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

    # Onde ficam as vilas. Lidas do mesmo arquivo que o mundo usa, para nao
    # existirem duas verdades sobre a posicao de uma cidade.
    var arquivo := FileAccess.open("res://data/regions.json", FileAccess.READ)
    if arquivo:
        var dados = JSON.parse_string(arquivo.get_as_text())
        if typeof(dados) == TYPE_DICTIONARY:
            var lado: float = float(dados.get("region_size", 120.0))
            var pracas: Dictionary = {}
            var plantas := FileAccess.open("res://data/city_layouts.json", FileAccess.READ)
            if plantas:
                var urbano = JSON.parse_string(plantas.get_as_text())
                if typeof(urbano) == TYPE_DICTIONARY:
                    pracas = urbano.get("pracas", {})
            for regiao in dados.get("regions", []):
                var reg_id := String(regiao.get("id", ""))
                var is_cidade: bool = String(regiao.get("biome", "")) == "cidade"
                var has_planta: bool = pracas.has(reg_id)
                if not is_cidade and not has_planta:
                    continue
                _vilas.append(Vector2(float(regiao["col"]) * lado,
                                      float(regiao["row"]) * lado))
                var praca: Dictionary = pracas.get(reg_id, {})
                _raios.append(float(praca.get("raio", RAIO_DA_VILA)))

                var aneis: Array = praca.get("aneis", [])
                _malhas.append(Vector4(
                    float(praca.get("avenidas", 0)),
                    float(aneis[0]) if aneis.size() > 0 else 0.0,
                    float(aneis[1]) if aneis.size() > 1 else 0.0,
                    float(aneis[2]) if aneis.size() > 2 else 0.0))

    var textura: Texture2D = load("res://textures/road_mask.png")
    if textura:
        _estradas = textura.get_image()

static func altura(x: float, z: float) -> float:
    _preparar()
    var natural := (_colinas.get_noise_2d(x, z) * ALTURA_DAS_COLINAS
        + _detalhe.get_noise_2d(x, z) * ALTURA_DO_RELEVO)

    var h := _nivelar_a_vila(x, z, natural)
    return _levantar_a_estrada(x, z, h)

## Achata o terreno em volta de cada vila.
##
## A altura do platô e a do CENTRO da vila, nao uma constante: assim a cidade
## continua no lugar que o relevo lhe deu, alta ou baixa, e so a superficie dela
## fica plana. Uma constante poria toda vila na mesma cota e criaria degrau na
## borda de umas e cratera na de outras.
static func _nivelar_a_vila(x: float, z: float, natural: float) -> float:
    for i in _vilas.size():
        var centro: Vector2 = _vilas[i]
        var raio: float = _raios[i]
        var distancia := Vector2(x, z).distance_to(centro)
        if distancia > raio + RAMPA_DA_VILA:
            continue
        var plato := (_colinas.get_noise_2d(centro.x, centro.y) * ALTURA_DAS_COLINAS
            + _detalhe.get_noise_2d(centro.x, centro.y) * ALTURA_DO_RELEVO)
        # Rampa suavizada nas duas pontas: transicao linear deixa uma quina
        # visivel onde o plato encontra o morro.
        var quanto := 1.0 - smoothstep(raio, raio + RAMPA_DA_VILA, distancia)
        return lerp(natural, plato, quanto)
    return natural

## Garante que a estrada nunca afunde abaixo da linha da agua.
static func _levantar_a_estrada(x: float, z: float, h: float) -> float:
    if _estradas == null or h > NIVEL_DA_AGUA + FOLGA_DA_ESTRADA:
        return h
    var uv := (Vector2(x, z) - _mundo_min) / _mundo_tam
    if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
        return h
    var pixel := _estradas.get_pixel(
        int(uv.x * float(_estradas.get_width() - 1)),
        int(uv.y * float(_estradas.get_height() - 1)))
    var na_estrada: float = maxf(pixel.r, pixel.g)
    if na_estrada < 0.35:
        return h
    return lerp(h, NIVEL_DA_AGUA + FOLGA_DA_ESTRADA, smoothstep(0.35, 0.8, na_estrada))

## Centro e raio de cada praca, para quem precisa saber onde a cidade comeca —
## hoje o shader do chao, que pavimenta o plato.
static func pracas() -> Array[Vector3]:
    _preparar()
    var lista: Array[Vector3] = []
    for i in _vilas.size():
        lista.append(Vector3(_vilas[i].x, _vilas[i].y, _raios[i]))
    return lista

## Raio do plato da vila cujo centro e este ponto, ou zero se ali nao ha vila.
static func raio_da_praca(centro: Vector3) -> float:
    _preparar()
    var alvo := Vector2(centro.x, centro.z)
    for i in _vilas.size():
        if _vilas[i].distance_to(alvo) < 1.0:
            return _raios[i]
    return 0.0

## A malha viaria de cada cidade, na ordem de pracas(). Vai para o shader do
## chao, que e quem desenha o leito das ruas.
static func malhas_viarias() -> Array[Vector4]:
    _preparar()
    return _malhas

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
