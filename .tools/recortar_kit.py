#!/usr/bin/env python3
"""Corta um kit de UI feito sobre fundo magenta em pecas soltas com alfa.

O gerador entrega tudo numa folha so, sobre magenta. Colar a folha inteira nao
serve; e preciso uma imagem por peca, com fundo transparente.

DUAS ARMADILHAS, as duas ja pagas neste projeto:

1. TIRAR O MAGENTA POR IGUALDADE EXATA deixa uma franja rosa na borda de tudo,
   porque a borda e mistura entre a peca e o fundo. Aqui o alfa sai da DISTANCIA
   ate o magenta e a cor e "descontaminada": o quanto de magenta vazou para o
   pixel e removido antes de ele virar borda.

2. PIXEL TRANSPARENTE COM COR ERRADA reaparece pelo mipmap. Onde o alfa e zero a
   cor nao e preta: ela e preenchida com a cor do vizinho opaco mais proximo
   (sangria de alfa). Sem isso o rosa volta assim que a textura reduz.

Uso: recortar_kit.py <folha.png> <pasta> [area_minima]
"""
import os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

FUNDO = np.array([255.0, 0.0, 255.0])
LIMITE = 150.0       # distancia ate o magenta em que a peca ja e opaca
PISO = 34.0          # abaixo disto e fundo, e nao brilho da peca
FORCA_DO_DESPILL = 1.0
AREA_MINIMA = 900


def alfa_e_cor(rgb):
    """Alfa pela distancia ao fundo, cor sem a contaminacao do fundo.

    DESCONTAMINAR NAO BASTA. A conta de composicao devolve a cor certa quando o
    alfa esta certo, mas a peca tem BRILHO: uma auréola de pixels 10 a 30 por
    cento opacos sobre magenta. Neles o alfa e pequeno, a divisao amplifica o
    erro e sobra rosa — a franja que ja apareceu nos Ecos.

    Por isso vem o despill depois: onde o vermelho e o azul passam do verde
    juntos, que e a assinatura do magenta, os dois sao puxados para baixo ate o
    verde. Um brilho branco-azulado nao perde nada; o rosa que nao pertence a
    peca some.
    """
    d = np.linalg.norm(rgb - FUNDO, axis=2)
    a = np.clip((d - PISO) / (LIMITE - PISO), 0.0, 1.0)
    seguro = np.maximum(a, 1e-4)[..., None]
    cor = (rgb - FUNDO * (1.0 - a)[..., None]) / seguro
    cor = np.clip(cor, 0, 255)
    r, g, b = cor[..., 0], cor[..., 1], cor[..., 2]
    magenta = np.minimum(r, b) - g
    excesso = np.clip(magenta, 0.0, None) * FORCA_DO_DESPILL
    cor[..., 0] = np.clip(r - excesso, 0, 255)
    cor[..., 2] = np.clip(b - excesso, 0, 255)
    return a, cor


def sangrar(cor, a, voltas=8):
    """Empurra a cor dos opacos para dentro dos transparentes."""
    solido = a > 0.02
    saida = cor.copy()
    for _ in range(voltas):
        falta = ~solido
        if not falta.any():
            break
        soma = np.zeros_like(saida)
        conta = np.zeros(a.shape)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            viz = np.roll(solido, (dy, dx), axis=(0, 1))
            vcor = np.roll(saida, (dy, dx), axis=(0, 1))
            usa = viz & falta
            soma[usa] += vcor[usa]
            conta[usa] += 1
        tem = conta > 0
        saida[tem] = soma[tem] / conta[tem][..., None]
        solido = solido | tem
    return saida


def main():
    folha, pasta = sys.argv[1], sys.argv[2]
    area_min = int(sys.argv[3]) if len(sys.argv) > 3 else AREA_MINIMA
    os.makedirs(pasta, exist_ok=True)
    rgb = np.asarray(Image.open(folha).convert("RGB"), dtype=np.float64)
    a, cor = alfa_e_cor(rgb)
    cor = sangrar(cor, a)

    # As pecas sao ilhas de alfa. Um fecho leve junta o que a borda separou.
    mascara = a > 0.35
    mascara = ndimage.binary_closing(mascara, np.ones((5, 5)))
    rotulos, quantas = ndimage.label(mascara)
    caixas = ndimage.find_objects(rotulos)

    achadas = []
    for i, cx in enumerate(caixas):
        if cx is None:
            continue
        ys, xs = cx
        alt, larg = ys.stop - ys.start, xs.stop - xs.start
        if alt * larg < area_min:
            continue
        achadas.append((ys.start, xs.start, ys.stop, xs.stop))

    # Ordena por linha (agrupando alturas parecidas) e depois por coluna, para os
    # nomes sairem na mesma ordem em que a folha se le.
    achadas.sort(key=lambda c: (c[0] // 60, c[1]))
    print("%d pecas de %d ilhas" % (len(achadas), quantas))
    for n, (y0, x0, y1, x1) in enumerate(achadas):
        recorte = np.dstack([cor[y0:y1, x0:x1], a[y0:y1, x0:x1] * 255.0])
        img = Image.fromarray(recorte.astype(np.uint8), "RGBA")
        nome = "peca_%02d.png" % n
        img.save(os.path.join(pasta, nome))
        print("  %-14s %4dx%-4d  em (%d, %d)" % (nome, x1 - x0, y1 - y0, x0, y0))


if __name__ == "__main__":
    main()
