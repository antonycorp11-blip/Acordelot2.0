#!/usr/bin/env python3
"""Sintetiza as notas que a espada toca ao golpear.

A lamina do Akles e um teclado. Entao o golpe nao faz "vum": ele toca uma NOTA.
E o jogo e de educacao musical — a nota tem que estar afinada de verdade, nao
ser um efeito sonoro qualquer.

Afinacao A4 = 440 Hz, temperamento igual. O timbre e aditivo: fundamental mais
harmonicos em queda, com ataque rapido e cauda longa, que e o desenho de uma
corda percutida.
"""
import math, struct, wave

TAXA = 44100
DURACAO = 1.4
SAIDA = "audio"

# Do maior, a escala com que o jogo comeca no capitulo 1.
NOTAS = {
    "do": 261.63, "re": 293.66, "mi": 329.63, "fa": 349.23,
    "sol": 392.00, "la": 440.00, "si": 493.88,
}

# Harmonico: (multiplo da fundamental, peso, quao rapido morre)
HARMONICOS = [(1.0, 1.00, 1.0), (2.0, 0.42, 1.6), (3.0, 0.22, 2.3),
              (4.0, 0.12, 3.1), (5.0, 0.07, 4.0), (6.0, 0.04, 5.2)]


def envelope(t, duracao):
    """Ataque de 6 ms e queda exponencial. Ataque instantaneo estala no
    alto-falante; queda linear soa a sintetizador de brinquedo."""
    ataque = 0.006
    if t < ataque:
        return t / ataque
    return math.exp(-3.2 * (t - ataque) / duracao)


def gerar(frequencia, caminho):
    quadros = int(TAXA * DURACAO)
    amostras = []
    for i in range(quadros):
        t = i / TAXA
        valor = 0.0
        for multiplo, peso, queda in HARMONICOS:
            # Harmonico agudo morre antes que o grave: e isso que faz o som
            # "amadurecer" em vez de ficar parado ate sumir.
            valor += peso * math.sin(TAU_POR_SEG * frequencia * multiplo * t) \
                * math.exp(-3.2 * queda * t / DURACAO)
        valor *= envelope(t, DURACAO)
        amostras.append(valor)

    pico = max(abs(v) for v in amostras) or 1.0
    with wave.open(caminho, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(TAXA)
        f.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, v / pico * 0.82)) * 32767))
            for v in amostras))


TAU_POR_SEG = 2.0 * math.pi

if __name__ == "__main__":
    for nome, frequencia in NOTAS.items():
        caminho = "%s/nota_%s.wav" % (SAIDA, nome)
        gerar(frequencia, caminho)
        print("%-4s %7.2f Hz  %s" % (nome, frequencia, caminho))
