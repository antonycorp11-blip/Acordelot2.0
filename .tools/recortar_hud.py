#!/usr/bin/env python3
"""Vaza o miolo das pecas do HUD para elas virarem moldura de verdade.

A arte do kit vem com o preenchimento PINTADO DENTRO: a barra de vida ja chega
com o vermelho em 89% e os numeros "1.850 / 2.020" desenhados por cima, e a
moldura do mapa chega com um mapa inteiro dentro. Colada assim na tela ela e um
adesivo: mostra sempre o mesmo valor.

Este remendo apaga o interior e guarda so a borda. O que era desenho vira
moldura, e a barra de progresso de verdade passa a aparecer por baixo dela.

De quebra tira a franja magenta que sobrou do recorte do fundo — pixel de borda
que ficou meio transparente e, contra o azul do ceu, aparece como um contorno
roxo em volta de cada peca.
"""
import os
import sys

from PIL import Image

PASTA = "textures/ui"

# Onde comeca o miolo de cada barra, em pixels da borda. Medido na propria arte:
# a moldura dourada ocupa os primeiros quatro ou cinco pixels, e o preenchimento
# comeca logo depois.
# As margens sao contadas a partir da BORDA DO DESENHO, nao da borda do arquivo:
# a barra de vida so comeca na linha 12 do PNG, e medir pelo arquivo apagava a
# rampa de cima inteira.
BARRAS = {
    "barra_vida.png": (8, 6),
    "barra_mana.png": (8, 6),
    # As pontas desta tem ornamento em forma de seta, que avanca bem mais para
    # dentro que a borda reta das outras duas.
    "barra_alvo.png": (17, 7),
}

# O circulo da moldura do mapa ocupa a imagem inteira; a faixa dourada tem uns
# nove pixels. O "N" fica por cima da borda e sobrevive por estar fora do miolo.
MOLDURA = ("moldura_mapa.png", 10)
# O "N" da bussola fica encostado na borda de cima e cairia dentro do miolo.
# So a caixa dele passa intacta — proteger a faixa inteira deixaria uma tira de
# floresta pintada atravessada no topo do minimapa.
CAIXA_DO_N = (214, 0, 281, 62)


def _vazar_retangulo(im, mx, my):
    px = im.load()
    # Caixa medida por LINHA E COLUNA CHEIA, nao pelo primeiro pixel opaco.
    # A barra de vida tem uma sujeira solta no alto do arquivo, e medir pelo
    # getbbox() colocava a borda seis pixels acima do desenho — o suficiente
    # para o vazamento comer a rampa de cima da moldura inteira.
    w, h = im.size
    px0 = im.load()
    def _cheia(pontos):
        return sum(1 for p in pontos if px0[p[0], p[1]][3] > 120)
    linhas = [y for y in range(h) if _cheia([(x, y) for x in range(w)]) > w * 0.5]
    colunas = [x for x in range(w) if _cheia([(x, y) for y in range(h)]) > h * 0.5]
    if not linhas or not colunas:
        return
    x0, y0, x1, y1 = colunas[0], linhas[0], colunas[-1] + 1, linhas[-1] + 1
    # O raio do canto sai da margem MENOR. Com a maior, a barra de alvo — que
    # tem margem lateral de 72 por causa dos ornamentos — protegia uma diagonal
    # enorme e deixava o vermelho pintado sobrando em cima e embaixo.
    raio = min(mx, my)
    for y in range(y0 + my, y1 - my):
        for x in range(x0 + mx, x1 - mx):
            # Deixa o canto em paz: dentro do raio de canto, so apaga o que
            # estiver na diagonal de dentro.
            perto_x = min(x - (x0 + mx), (x1 - mx) - x)
            perto_y = min(y - (y0 + my), (y1 - my) - y)
            if perto_x < raio and perto_y < raio:
                dx = raio - perto_x
                dy = raio - perto_y
                if dx * dx + dy * dy > raio * raio:
                    continue
            r, g, b, _ = px[x, y]
            px[x, y] = (r, g, b, 0)


def _vazar_circulo(im, faixa):
    px = im.load()
    w, h = im.size
    cx, cy = (w - 1) / 2.0, (h - 1) / 2.0
    dentro = min(cx, cy) - faixa
    for y in range(h):
        for x in range(w):
            nx0, ny0, nx1, ny1 = CAIXA_DO_N
            if nx0 <= x <= nx1 and ny0 <= y <= ny1:
                # Dentro da caixa do "N" so o dourado da letra fica; o resto e
                # a floresta pintada do mapa de exemplo, e ficaria como um
                # selo verde grudado no topo do minimapa.
                r, g, b, _a = px[x, y]
                if r > 140 and g > 105 and b < 130 and r > b + 45:
                    continue
            dx, dy = x - cx, y - cy
            if dx * dx + dy * dy <= dentro * dentro:
                r, g, b, _ = px[x, y]
                px[x, y] = (r, g, b, 0)


def _tirar_franja(im):
    """Zera o pixel meio transparente que ainda puxa para o magenta."""
    px = im.load()
    w, h = im.size
    limpos = 0
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0 or a > 200:
                continue
            # Magenta e vermelho e azul altos com o verde no chao.
            if r > 60 and b > 60 and g < min(r, b) * 0.55:
                px[x, y] = (r, g, b, 0)
                limpos += 1
    return limpos


def main():
    if not os.path.isdir(PASTA):
        print("rode a partir da raiz do projeto")
        return

    for nome, (mx, my) in BARRAS.items():
        caminho = os.path.join(PASTA, nome)
        im = Image.open(caminho).convert("RGBA")
        _vazar_retangulo(im, mx, my)
        franja = _tirar_franja(im)
        im.save(caminho)
        print(f"{nome:20} miolo vazado ({mx},{my})  franja {franja}")

    nome, faixa = MOLDURA
    caminho = os.path.join(PASTA, nome)
    im = Image.open(caminho).convert("RGBA")
    _vazar_circulo(im, faixa)
    franja = _tirar_franja(im)
    im.save(caminho)
    print(f"{nome:20} circulo vazado (faixa {faixa})  franja {franja}")

    for nome in ("retrato.png", "btn_config.png", "btn_mochila.png",
                 "joystick_base.png", "joystick_botao.png"):
        caminho = os.path.join(PASTA, nome)
        if not os.path.exists(caminho):
            continue
        im = Image.open(caminho).convert("RGBA")
        franja = _tirar_franja(im)
        if franja:
            im.save(caminho)
        print(f"{nome:20} franja {franja}")


main()
