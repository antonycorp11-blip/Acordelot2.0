#!/usr/bin/env python3
"""Recorta a folha irregular do Eco de Do em frames transparentes.

A folha nao e uma grade: idle e hurt inclusive trazem menos quadros visiveis
que o texto impresso. Cada faixa e cada janela horizontal foram medidas na
arte. Todos os resultados usam a mesma tela e a mesma linha de base.
"""

from pathlib import Path
import sys

import cv2
import numpy as np
from PIL import Image


ANIMACOES = {
    "idle": {
        "y": (0, 184), "base": 168, "fps": 7.0, "loop": True,
        "quadros": [(175, 346), (346, 537), (537, 728), (728, 921), (921, 1115)],
    },
    "walk": {
        "y": (184, 365), "base": 348, "fps": 9.0, "loop": True,
        "quadros": [(175, 327), (327, 513), (513, 698), (698, 881),
                    (881, 1062), (1062, 1241), (1241, 1410), (1410, 1536)],
    },
    "run": {
        "y": (365, 540), "base": 522, "fps": 11.0, "loop": True,
        "quadros": [(175, 347), (347, 541), (541, 735),
                    (735, 930), (930, 1120), (1120, 1335)],
    },
    "attack": {
        "y": (535, 715), "base": 703, "fps": 11.0, "loop": False,
        # O quarto quadro e deliberadamente largo: e a onda musical completa.
        "quadros": [(175, 325), (325, 490), (490, 730),
                    (730, 1050), (1050, 1230), (1230, 1475)],
    },
    "hurt": {
        "y": (710, 870), "base": 850, "fps": 9.0, "loop": False,
        "quadros": [(175, 330), (330, 520), (520, 715)],
    },
    "disappear": {
        "y": (870, 1024), "base": 1015, "fps": 10.0, "loop": False,
        "quadros": [(175, 347), (347, 540), (540, 707),
                    (707, 872), (872, 1057), (1057, 1250)],
    },
}

CANVAS = (768, 220)
BASE_CANVAS = 205


def _caracteristicas(x: np.ndarray, y: np.ndarray) -> np.ndarray:
    return np.column_stack((np.ones_like(x), x, y, x * y, x * x, y * y,
                            x * x * x, y * y * y))


def remover_fundo(imagem: Image.Image) -> Image.Image:
    """Subtrai o gradiente magenta real, em vez de procurar uma cor fixa."""
    rgb = np.asarray(imagem.convert("RGB"), dtype=np.float32)
    altura, largura = rgb.shape[:2]
    yy, xx = np.mgrid[0:altura:4, 0:largura:4]
    amostra = rgb[::4, ::4]
    r, g, b = amostra[..., 0], amostra[..., 1], amostra[..., 2]
    candidato = ((r > 150) & (b > 125) & (g < 85) &
                 (r - g > 90) & (b - g > 85) & (np.abs(r - b) < 75))
    x = xx[candidato] / max(largura - 1, 1)
    y = yy[candidato] / max(altura - 1, 1)
    cores = amostra[candidato]
    matriz = _caracteristicas(x, y)

    # Duas passagens retiram do ajuste os poucos pixels rosa do proprio Eco.
    valido = np.ones(len(cores), dtype=bool)
    coef = None
    for _ in range(2):
        coef = np.linalg.lstsq(matriz[valido], cores[valido], rcond=None)[0]
        residuo = np.linalg.norm(matriz @ coef - cores, axis=1)
        valido = residuo < 18.0

    x_t = np.arange(largura, dtype=np.float32) / max(largura - 1, 1)
    y_t = np.arange(altura, dtype=np.float32) / max(altura - 1, 1)
    grade_x, grade_y = np.meshgrid(x_t, y_t)
    fundo = (_caracteristicas(grade_x.ravel(), grade_y.ravel()) @ coef).reshape(altura, largura, 3)
    distancia = np.linalg.norm(rgb - fundo, axis=2)
    alfa = np.clip((distancia - 11.0) / 52.0, 0.0, 1.0)

    # Remove ruido isolado de um pixel, mas preserva as pequenas notas musicais.
    mascara = (alfa > 0.08).astype(np.uint8)
    numero, rotulos, estatisticas, _ = cv2.connectedComponentsWithStats(mascara, 8)
    manter = np.zeros_like(mascara)
    for indice in range(1, numero):
        if estatisticas[indice, cv2.CC_STAT_AREA] >= 2:
            manter[rotulos == indice] = 1
    alfa *= manter

    # Descontamina o antialias: recupera a cor anterior a mistura com magenta.
    a = np.maximum(alfa[..., None], 1.0 / 255.0)
    cor = np.clip((rgb - (1.0 - a) * fundo) / a, 0.0, 255.0)
    saida = np.dstack((cor, alfa[..., None] * 255.0)).astype(np.uint8)
    saida[alfa <= 0.0] = 0
    return Image.fromarray(saida, "RGBA")


def recortar(folha: Image.Image, destino: Path) -> dict[str, list[Path]]:
    transparente = remover_fundo(folha)
    arquivos = {}
    for animacao, dados in ANIMACOES.items():
        pasta = destino / animacao
        pasta.mkdir(parents=True, exist_ok=True)
        y0, y1 = dados["y"]
        faixa = np.asarray(transparente.crop((0, y0, folha.width, y1))).copy()
        mascara = (faixa[..., 3] > 18).astype(np.uint8)
        numero, rotulos, estatisticas, centroides = cv2.connectedComponentsWithStats(mascara, 8)
        arquivos[animacao] = []
        for indice, (x0, x1) in enumerate(dados["quadros"]):
            # As poses se sobrepoem horizontalmente na prancha. Recortar um
            # retangulo trazia a cabeca/cauda do quadro vizinho. Componentes
            # inteiros sao atribuidos ao quadro pelo CENTRO, portanto a pose e
            # preservada mesmo quando uma asa cruza o limite entre duas janelas.
            escolhidos = [i for i in range(1, numero)
                           if estatisticas[i, cv2.CC_STAT_AREA] >= 2
                           and x0 <= centroides[i, 0] < x1
                           # O nome da faixa invade a primeira janela. Ele e
                           # branco e fica no topo; a criatura comeca bem abaixo.
                           and not (indice == 0 and centroides[i, 0] < 270
                                    and centroides[i, 1] < 48)]
            selecao = np.isin(rotulos, escolhidos)
            pixels = faixa.copy()
            pixels[~selecao] = 0
            quadro_largo = Image.fromarray(pixels, "RGBA")
            caixa_larga = quadro_largo.getchannel("A").point(lambda a: 255 if a > 18 else 0).getbbox()
            if caixa_larga is None:
                raise RuntimeError(f"quadro vazio: {animacao} {indice}")
            quadro = quadro_largo.crop((caixa_larga[0], 0, caixa_larga[2], y1 - y0))
            caixa = quadro.getchannel("A").point(lambda a: 255 if a > 18 else 0).getbbox()
            centro_x = (caixa[0] + caixa[2]) // 2
            tela = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
            destino_x = CANVAS[0] // 2 - centro_x
            destino_y = BASE_CANVAS - (int(dados["base"]) - y0)
            tela.alpha_composite(quadro, (destino_x, destino_y))
            caminho = pasta / f"frame_{indice:02d}.png"
            tela.save(caminho, optimize=True)
            arquivos[animacao].append(caminho)
            print(f"{animacao}/{caminho.name}")
    return arquivos


def escrever_sprite_frames(arquivos: dict[str, list[Path]], destino: Path) -> None:
    recursos = []
    ids = {}
    contador = 1
    for animacao, quadros in arquivos.items():
        for quadro in quadros:
            ident = f"{contador}_{animacao}_{quadro.stem}"
            caminho_res = "res://" + str(quadro).split("/textures/", 1)[1]
            caminho_res = "res://textures/" + caminho_res.split("res://", 1)[1]
            recursos.append(f'[ext_resource type="Texture2D" path="{caminho_res}" id="{ident}"]')
            ids[quadro] = ident
            contador += 1

    animacoes = []
    for nome, quadros in arquivos.items():
        frames = ", ".join(
            '{"duration": 1.0, "texture": ExtResource("%s")}' % ids[q]
            for q in quadros)
        dados = ANIMACOES[nome]
        animacoes.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' %
            (frames, "true" if dados["loop"] else "false", nome, dados["fps"]))

    texto = '[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n%s\n\n[resource]\nanimations = [%s]\n' % (
        contador, "\n".join(recursos), ", ".join(animacoes))
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(texto, encoding="utf-8")


def main() -> None:
    if len(sys.argv) != 4:
        raise SystemExit("uso: recortar_eco_do.py FOLHA.png PASTA_FRAMES SpriteFrames.tres")
    folha, pasta, recurso = map(Path, sys.argv[1:])
    arquivos = recortar(Image.open(folha), pasta)
    escrever_sprite_frames(arquivos, recurso)


if __name__ == "__main__":
    main()
