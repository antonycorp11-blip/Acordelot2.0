extends Node
## A TRILHA E FEITA COM AS NOTAS DO PROPRIO JOGO.
##
## Nao ha musica gravada no projeto, e por um bom motivo: encomendar faixa e
## caro e um arquivo de audio pesa mais que tudo que eu economizei no pacote. O
## que existe sao as sete notas naturais em `audio/`, as mesmas que tocam quando
## o Akles acerta um golpe e quando um Eco entra na afinacao.
##
## Entao a trilha e TOCADA, nao reproduzida: um andamento lento sobre uma
## progressao de acordes, com cada nota saindo do proprio arquivo e transposta
## por oitava com `pitch_scale`. A cidade anda em tom maior; a caverna desce
## para o menor, mais grave e mais espacada. Num jogo de educacao musical isso
## nao e economia — a trilha e feita do material que o jogo ensina.
##
## Fica baixa de proposito. A instrucao foi "vai existir e nao vai incomodar".

const NOTAS := {
    "do": preload("res://audio/nota_do.wav"),
    "re": preload("res://audio/nota_re.wav"),
    "mi": preload("res://audio/nota_mi.wav"),
    "fa": preload("res://audio/nota_fa.wav"),
    "sol": preload("res://audio/nota_sol.wav"),
    "la": preload("res://audio/nota_la.wav"),
    "si": preload("res://audio/nota_si.wav"),
}
const ORDEM := ["do", "re", "mi", "fa", "sol", "la", "si"]

## Uma progressao e uma lista de acordes; cada acorde e um grau da escala. Em
## graus, e nao em nomes de nota: assim a mesma progressao serve em qualquer
## tonalidade, que e como harmonia funciona de verdade.
const CLIMAS := {
    "mundo": {
        "progressao": [[0, 2, 4], [3, 5, 0], [4, 6, 1], [5, 0, 2]],
        "compasso": 3.4, "oitava": 0, "volume": -19.0, "arpejo": 0.42,
        "brilho": 1.0,
    },
    "cidade": {
        "progressao": [[0, 2, 4], [5, 0, 2], [3, 5, 0], [4, 6, 1]],
        "compasso": 3.0, "oitava": 0, "volume": -17.5, "arpejo": 0.34,
        "brilho": 1.0,
    },
    # A caverna usa o relativo menor da mesma escala — sexto grau como centro.
    # Mesma armadura, outro humor: e a licao do Eco de Lá virando ambiente.
    "caverna": {
        "progressao": [[5, 0, 2], [3, 5, 0], [4, 6, 1], [5, 0, 2]],
        "compasso": 4.6, "oitava": -1, "volume": -20.0, "arpejo": 0.62,
        "brilho": 0.82,
    },
}

var _vozes: Array[AudioStreamPlayer] = []
var _proxima_voz := 0
var _clima := "mundo"
var _acorde := 0
var _ate_o_proximo := 1.5
var _ligada := true


func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    # Quatro vozes bastam: tres do acorde e uma sobrando para a nota anterior
    # ainda estar morrendo quando a seguinte entra. E o que da liga entre um
    # compasso e o outro.
    for i in 4:
        var v := AudioStreamPlayer.new()
        v.bus = "Master"
        add_child(v)
        _vozes.append(v)


func definir_clima(qual: String) -> void:
    if not CLIMAS.has(qual) or qual == _clima:
        return
    _clima = qual
    _acorde = 0
    _ate_o_proximo = 0.8


func ligar(sim: bool) -> void:
    _ligada = sim
    if not sim:
        for v in _vozes:
            v.stop()


func _process(delta: float) -> void:
    if not _ligada:
        return
    _ate_o_proximo -= delta
    if _ate_o_proximo > 0.0:
        return
    var c: Dictionary = CLIMAS[_clima]
    _ate_o_proximo = float(c["compasso"])
    var graus: Array = c["progressao"][_acorde % c["progressao"].size()]
    _acorde += 1
    for i in graus.size():
        _soar(int(graus[i]), int(c["oitava"]), float(c["volume"]),
            float(c["arpejo"]) * float(i), float(c["brilho"]))


## Toca um grau da escala. O grau passa de sete e sobe de oitava sozinho, que e
## o que faz a progressao respirar em vez de andar sempre no mesmo punhado.
func _soar(grau: int, oitava: int, volume: float, atraso: float, brilho: float) -> void:
    var indice: int = grau % ORDEM.size()
    var salto: int = oitava + int(floor(float(grau) / float(ORDEM.size())))
    var voz := _vozes[_proxima_voz % _vozes.size()]
    _proxima_voz += 1
    voz.stream = NOTAS[ORDEM[indice]]
    voz.pitch_scale = pow(2.0, float(salto)) * brilho
    voz.volume_db = volume
    if atraso <= 0.001:
        voz.play()
        return
    var relogio := get_tree().create_timer(atraso)
    relogio.timeout.connect(func():
        if _ligada and is_instance_valid(voz):
            voz.play())
