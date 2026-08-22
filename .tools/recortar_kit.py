#!/usr/bin/env python3
"""Recorta uma folha de arte de interface em pecas soltas, com alfa.

A arte da interface chega em FOLHA: seis botoes numa imagem, vinte icones em
outra. O jogo nao usa folha — usa peca, uma por moldura, uma por icone, cada
uma no seu arquivo, para o Godot importar e o codigo pedir pelo nome.

Tres passos, nesta ordem, e a ordem importa:

1. O magenta vira transparencia. E o fundo combinado com o gerador de imagem:
   cor que nao existe em nenhum objeto do jogo, entao chavear por ela nao come
   pedaco de peca nenhuma.
2. A franja roxa sai. Na borda de cada peca o magenta se mistura com a arte e
   deixa um halo violeta que aparece contra o azul do painel. Onde vermelho e
   azul passam do verde, o excesso e do fundo e volta ao nivel do verde.
3. As ilhas de pixel ficam separadas. Cada mancha de opaco cercada de vazio e
   uma peca; a biblioteca rotula as ilhas e cada rotulo vira um recorte.

Uso: recortar_kit.py destino/ folha.png [folha.png ...]
"""
import os
import sys

import numpy as np
from PIL import Image
from scipy import ndimage

# Quao longe do verde o vermelho e o azul precisam estar para o pixel ser fundo.
# Folga alta de proposito: o gerador entrega o magenta com leve gradiente, e
# limite justo deixa faixas do fundo sobrando nos cantos da imagem.
LIMITE_FUNDO = 60
# Abaixo disto e sujeira: pontinho solto do gerador, nao peca.
MENOR_PECA = 900
# Ilhas mais proximas que isto sao a MESMA peca — o brilho de uma moldura se
# rompe em fiapos, e sem juntar sairiam vinte cacos no lugar de um icone.
COLA = 3


def _chavear(imagem):
    dados = np.array(imagem.convert("RGBA")).astype(np.int16)
    r, g, b = dados[..., 0], dados[..., 1], dados[..., 2]
    fundo = (r - g > LIMITE_FUNDO) & (b - g > LIMITE_FUNDO)
    dados[..., 3] = np.where(fundo, 0, 255)

    # A franja: o teto do vermelho e do azul passa a ser o verde mais um dedo.
    teto = g + 28
    visivel = ~fundo
    dados[..., 0] = np.where(visivel & (r > teto), teto, r)
    dados[..., 2] = np.where(visivel & (b > teto), teto, b)
    return dados.clip(0, 255).astype(np.uint8), ~fundo


def recortar(caminho, destino):
    imagem = Image.open(caminho)
    dados, cheio = _chavear(imagem)
    recortada = Image.fromarray(dados, "RGBA")

    # Engorda a mascara para colar os fiapos, rotula, e mede as caixas na
    # mascara ORIGINAL — a engorda serve para agrupar, nao para recortar.
    inchada = ndimage.binary_dilation(cheio, iterations=COLA)
    rotulos, quantos = ndimage.label(inchada)

    nome = os.path.splitext(os.path.basename(caminho))[0]
    pasta = os.path.join(destino, nome)
    os.makedirs(pasta, exist_ok=True)

    caixas = []
    for i in range(1, quantos + 1):
        ys, xs = np.where((rotulos == i) & cheio)
        if ys.size < MENOR_PECA:
            continue
        caixas.append((ys.min(), xs.min(), ys.max() + 1, xs.max() + 1))

    # De cima para baixo, da esquerda para a direita — a ordem em que a folha
    # foi desenhada, para o numero do arquivo bater com o que se ve na imagem.
    # A linha e arredondada: pecas da mesma fileira nunca comecam no mesmo pixel.
    altura_media = max(1, int(np.median([c[2] - c[0] for c in caixas]))) if caixas else 1
    caixas.sort(key=lambda c: (round(c[0] / (altura_media * 0.6)), c[1]))

    for indice, (y0, x0, y1, x1) in enumerate(caixas):
        peca = recortada.crop((x0, y0, x1, y1))
        peca.save(os.path.join(pasta, "%02d.png" % indice))

    print("%-28s %3d pecas  ->  %s" % (os.path.basename(caminho), len(caixas), pasta))
    return len(caixas)


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return
    destino = sys.argv[1]
    for folha in sys.argv[2:]:
        recortar(folha, destino)


main()
