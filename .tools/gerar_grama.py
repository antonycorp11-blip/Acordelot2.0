#!/usr/bin/env python3
"""Gera uma textura de grama sem emenda para o chao do mundo.

A textura antiga era 'grama + terra' com trilha marcada: repetida a cada 16 m,
as trilhas viravam uma grade de lama visivel no mundo inteiro. Grama boa para
tilar tem que ser SEM elemento grande — so folha, com variacao de tom fina.

Sem emenda de verdade: cada folha desenhada perto da borda e desenhada de novo
do outro lado (o mesmo truque do modulo), entao o encaixe e exato.
"""
import math, random
from PIL import Image, ImageDraw, ImageFilter

TAM = 1024
SAIDA = "textures/grass_seamless.png"

# Verdes de campo iluminado. O intervalo e estreito de proposito: verde demais
# variado vira mato de video-game; o que da vida e a QUANTIDADE de folhas.
BASE_ESCURA = (46, 78, 34)
BASE_CLARA = (92, 132, 52)
FOLHA_ESCURA = (58, 96, 38)
FOLha_CLARA = (140, 178, 78)


def ruido_suave(rng, tam, celulas, oitavas=3):
    """Manchas suaves para o fundo — nuvem de valor entre 0 e 1."""
    acumulado = Image.new("L", (tam, tam), 0)
    peso_total = 0.0
    for oitava in range(oitavas):
        n = celulas * (2 ** oitava)
        peso = 1.0 / (2 ** oitava)
        pequeno = Image.new("L", (n, n))
        pequeno.putdata([rng.randrange(256) for _ in range(n * n)])
        # BICUBIC num tile pequeno mantem a continuidade nas bordas.
        camada = pequeno.resize((tam, tam), Image.BICUBIC)
        acumulado = Image.blend(acumulado, camada, peso / (peso_total + peso))
        peso_total += peso
    return acumulado.filter(ImageFilter.GaussianBlur(2))


def main():
    rng = random.Random(20260818)
    manchas = ruido_suave(rng, TAM, 4)

    # Fundo: interpola entre o verde escuro e o claro conforme a mancha.
    fundo = Image.new("RGB", (TAM, TAM))
    px_manchas = manchas.load()
    px_fundo = fundo.load()
    for y in range(TAM):
        for x in range(TAM):
            t = px_manchas[x, y] / 255.0
            px_fundo[x, y] = tuple(
                int(BASE_ESCURA[c] + (BASE_CLARA[c] - BASE_ESCURA[c]) * t) for c in range(3))

    desenho = ImageDraw.Draw(fundo)

    def folha(x, y, comprimento, inclinacao, cor, largura):
        """Uma folha: risco curvo de baixo para cima, repetido nas 8 vizinhancas
        para que o que sai por uma borda entre pela oposta."""
        for dx in (-TAM, 0, TAM):
            for dy in (-TAM, 0, TAM):
                px, py = x + dx, y + dy
                if px < -60 or px > TAM + 60 or py < -60 or py > TAM + 60:
                    continue
                pontos = []
                for passo in range(5):
                    f = passo / 4.0
                    pontos.append((
                        px + math.sin(inclinacao) * comprimento * f * f,
                        py - comprimento * f,
                    ))
                desenho.line(pontos, fill=cor, width=largura, joint="curve")

    # Duas camadas: as escuras dao volume no fundo, as claras pegam a luz.
    for _ in range(26000):
        x, y = rng.uniform(0, TAM), rng.uniform(0, TAM)
        tom = rng.random()
        cor = tuple(int(FOLHA_ESCURA[c] + (FOLha_CLARA[c] - FOLHA_ESCURA[c]) * tom)
                    for c in range(3))
        folha(x, y, rng.uniform(7, 17), rng.uniform(-0.7, 0.7), cor, 1)

    for _ in range(9000):
        x, y = rng.uniform(0, TAM), rng.uniform(0, TAM)
        cor = tuple(min(255, int(FOLha_CLARA[c] * rng.uniform(0.95, 1.12))) for c in range(3))
        folha(x, y, rng.uniform(11, 22), rng.uniform(-0.9, 0.9), cor, 2)

    fundo = fundo.filter(ImageFilter.SMOOTH)
    fundo.save(SAIDA)
    print("gerado", SAIDA, fundo.size)


if __name__ == "__main__":
    main()
