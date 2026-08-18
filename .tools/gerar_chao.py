#!/usr/bin/env python3
"""Gera as texturas de chao: grama e terra batida, ambas sem emenda.

Duas licoes que custaram tela feia:

1. **Um campo de grama uniforme parece carpete de cima.** A referencia que o dono
   mandou nao tem campo nenhum: tem terra batida com mancha de mato, flor e
   pedrisco. Por isso sao DUAS texturas — o shader mistura as duas por ruido de
   escala grande, e e a mistura que cria trilha e clareira.

2. **O celular entrega cor mais saturada que o desktop.** Em vez de perseguir
   parametro de renderizacao aparelho por aparelho, a arte ja nasce dessaturada
   e escura: assim nao ha o que estourar.

Sem emenda de verdade: o que e desenhado perto da borda e desenhado de novo do
outro lado, entao o encaixe e exato.
"""
import math, random, sys
from PIL import Image, ImageDraw, ImageFilter

TAM = 1024

# Paleta tirada da referencia: verde-oliva acinzentado, nao verde de tela de
# fundo. O valor medio fica por volta de 0.30 — de proposito baixo.
GRAMA_ESCURA = (44, 58, 32)
GRAMA_CLARA = (92, 106, 56)
FOLHA_ESCURA = (52, 68, 36)
FOLHA_CLARA = (116, 128, 72)

# Terra batida quente, o tom do caminho da referencia.
TERRA_ESCURA = (72, 60, 44)
TERRA_CLARA = (126, 108, 82)
PEDRA = (138, 132, 120)


def sem_emenda(imagem, operacao):
    """Aplica uma operacao de vizinhanca (desfoque, suavizacao) SEM quebrar a
    borda: ladrilha 3x3, opera e recorta o centro.

    Foi o que faltava na primeira versao. Desenhei as folhas repetindo nas
    bordas, mas o fundo ampliado e o desfoque final ignoravam a divisa — e a
    emenda resultante desenhava uma grade de 7 em 7 metros no mundo inteiro,
    que eu passei um bom tempo procurando na geometria.
    """
    ladrilhado = Image.new(imagem.mode, (TAM * 3, TAM * 3))
    for dx in range(3):
        for dy in range(3):
            ladrilhado.paste(imagem, (dx * TAM, dy * TAM))
    return operacao(ladrilhado).crop((TAM, TAM, TAM * 2, TAM * 2))


def manchas(rng, celulas, oitavas=3):
    acumulado = Image.new("L", (TAM, TAM), 0)
    peso_total = 0.0
    for oitava in range(oitavas):
        n = celulas * (2 ** oitava)
        peso = 1.0 / (2 ** oitava)
        pequeno = Image.new("L", (n, n))
        pequeno.putdata([rng.randrange(256) for _ in range(n * n)])
        largo = Image.new("L", (n * 3, n * 3))
        for dx in range(3):
            for dy in range(3):
                largo.paste(pequeno, (dx * n, dy * n))
        camada = largo.resize((TAM * 3, TAM * 3), Image.BICUBIC).crop(
            (TAM, TAM, TAM * 2, TAM * 2))
        acumulado = Image.blend(acumulado, camada, peso / (peso_total + peso))
        peso_total += peso
    return sem_emenda(acumulado, lambda i: i.filter(ImageFilter.GaussianBlur(2)))


def fundo_interpolado(mapa, escura, clara):
    imagem = Image.new("RGB", (TAM, TAM))
    px_mapa, px = mapa.load(), imagem.load()
    for y in range(TAM):
        for x in range(TAM):
            t = px_mapa[x, y] / 255.0
            px[x, y] = tuple(int(escura[c] + (clara[c] - escura[c]) * t) for c in range(3))
    return imagem


def repetido(desenhar):
    """Chama o desenho nas nove vizinhancas: o que sai por uma borda entra pela
    oposta, que e o que faz a textura encaixar consigo mesma."""
    for dx in (-TAM, 0, TAM):
        for dy in (-TAM, 0, TAM):
            desenhar(dx, dy)


def gerar_grama(rng):
    imagem = fundo_interpolado(manchas(rng, 4), GRAMA_ESCURA, GRAMA_CLARA)
    desenho = ImageDraw.Draw(imagem)

    def folha(x, y, comprimento, inclinacao, cor, largura):
        def traco(dx, dy):
            px, py = x + dx, y + dy
            if px < -60 or px > TAM + 60 or py < -60 or py > TAM + 60:
                return
            pontos = [(px + math.sin(inclinacao) * comprimento * (p / 4.0) ** 2,
                       py - comprimento * (p / 4.0)) for p in range(5)]
            desenho.line(pontos, fill=cor, width=largura, joint="curve")
        repetido(traco)

    for _ in range(24000):
        tom = rng.random()
        cor = tuple(int(FOLHA_ESCURA[c] + (FOLHA_CLARA[c] - FOLHA_ESCURA[c]) * tom)
                    for c in range(3))
        folha(rng.uniform(0, TAM), rng.uniform(0, TAM),
              rng.uniform(7, 16), rng.uniform(-0.7, 0.7), cor, 1)

    # Flor: o detalhe que a referencia tem e que a gente nao tinha. Poucas e
    # pequenas — muitas viram confete e denunciam a repeticao.
    for _ in range(260):
        cor = rng.choice([(146, 132, 178), (176, 172, 190), (188, 178, 120)])
        raio = rng.uniform(1.6, 2.8)
        x, y = rng.uniform(0, TAM), rng.uniform(0, TAM)
        repetido(lambda dx, dy: desenho.ellipse(
            [x + dx - raio, y + dy - raio, x + dx + raio, y + dy + raio], fill=cor))

    return sem_emenda(imagem, lambda i: i.filter(ImageFilter.SMOOTH))


def gerar_terra(rng):
    imagem = fundo_interpolado(manchas(rng, 5), TERRA_ESCURA, TERRA_CLARA)
    desenho = ImageDraw.Draw(imagem)

    # Pedrisco: o que faz terra batida parecer pisada, e nao papel pardo.
    for _ in range(2600):
        raio = rng.uniform(1.0, 3.4)
        claro = rng.uniform(0.55, 1.0)
        cor = tuple(int(PEDRA[c] * claro) for c in range(3))
        x, y = rng.uniform(0, TAM), rng.uniform(0, TAM)
        repetido(lambda dx, dy: desenho.ellipse(
            [x + dx - raio, y + dy - raio, x + dx + raio, y + dy + raio], fill=cor))

    # Sulcos rasos na direcao do caminho.
    for _ in range(70):
        x, y = rng.uniform(0, TAM), rng.uniform(0, TAM)
        comprimento = rng.uniform(30, 90)
        angulo = rng.uniform(0, math.pi)
        cor = tuple(int(TERRA_ESCURA[c] * rng.uniform(1.05, 1.25)) for c in range(3))
        repetido(lambda dx, dy: desenho.line(
            [(x + dx, y + dy),
             (x + dx + math.cos(angulo) * comprimento,
              y + dy + math.sin(angulo) * comprimento)], fill=cor, width=5))

    return sem_emenda(imagem, lambda i: i.filter(ImageFilter.GaussianBlur(0.6)))


def main():
    rng = random.Random(20260818)
    gerar_grama(rng).save("textures/grass_seamless.png")
    print("textures/grass_seamless.png")
    gerar_terra(random.Random(4242)).save("textures/dirt_seamless.png")
    print("textures/dirt_seamless.png")


if __name__ == "__main__":
    main()
