#!/usr/bin/env python3
from __future__ import annotations
"""Recorta folhas irregulares de Ecos e cria um atlas leve por criatura.

As poses nao formam uma grade perfeita. Cada faixa e cada janela horizontal
foram medidas na folha 1280x720; componentes inteiros sao atribuidos pelo
centro para nao cortar asas, caudas, notas ou o efeito largo da skill.
"""

from pathlib import Path
import sys

try:
    import cv2
except ModuleNotFoundError:
    cv2 = None
try:
    import numpy as np
except ModuleNotFoundError:
    np = None
from PIL import Image


ECOS = [
    (1, "ambar"), (2, "rubi"), (3, "cervo_dourado"),
    (4, "folha"), (5, "agua"), (6, "clave_azul"),
    (7, "safira"), (8, "ametista"), (9, "draconico"),
    (10, "celeste"),
]

ANIMACOES = {
    "idle": {
        "y": (0, 137), "base": 124, "fps": 7.0, "loop": True,
        "quadros": [(130, 275), (275, 430), (430, 585), (585, 740), (740, 910)],
    },
    "walk": {
        "y": (132, 269), "base": 253, "fps": 9.0, "loop": True,
        "quadros": [(130, 260), (260, 397), (397, 535), (535, 671),
                    (671, 806), (806, 940), (940, 1074), (1074, 1265)],
    },
    "run": {
        "y": (265, 385), "base": 371, "fps": 11.0, "loop": True,
        "quadros": [(125, 280), (280, 455), (455, 630),
                    (630, 805), (805, 980), (980, 1185)],
    },
    "attack": {
        "y": (380, 516), "base": 504, "fps": 11.0, "loop": False,
        "quadros": [(125, 257), (257, 390), (390, 540),
                    (540, 900), (900, 1080), (1080, 1275)],
    },
    "hurt": {
        "y": (510, 612), "base": 599, "fps": 9.0, "loop": False,
        "quadros": [(130, 263), (263, 404), (404, 570)],
    },
    "disappear": {
        "y": (605, 720), "base": 708, "fps": 10.0, "loop": False,
        "quadros": [(130, 275), (275, 425), (425, 575),
                    (575, 730), (730, 885), (885, 1050)],
    },
}

# No mundo cada Eco mede menos de um metro. A celula anterior (240x80) fazia
# dez atlas ocuparem quase 28 MiB de VRAM RGBA no navegador, embora o desenho
# apareca com poucas dezenas de pixels no celular. 192x64 preserva a leitura e
# reduz em 36% tanto a area de textura quanto o upload para a GPU.
CELULA = (192, 64)
COLUNAS = 4
BASE_CELULA = 58


def _caracteristicas(x: np.ndarray, y: np.ndarray) -> np.ndarray:
    return np.column_stack((np.ones_like(x), x, y, x * y, x * x, y * y,
                            x * x * x, y * y * y))


def remover_fundo(imagem: Image.Image) -> Image.Image:
    """Subtrai o gradiente magenta da foto e descontamina o antialias."""
    if cv2 is None or np is None:
        raise RuntimeError("recorte completo requer opencv; use --reduzir-existentes")
    rgb = np.asarray(imagem.convert("RGB"), dtype=np.float32)
    altura, largura = rgb.shape[:2]
    yy, xx = np.mgrid[0:altura:4, 0:largura:4]
    amostra = rgb[::4, ::4]
    r, g, b = amostra[..., 0], amostra[..., 1], amostra[..., 2]
    candidato = ((r > 145) & (b > 115) & (g < 105) &
                 (r - g > 75) & (b - g > 65) & (np.abs(r - b) < 95))
    x = xx[candidato] / max(largura - 1, 1)
    y = yy[candidato] / max(altura - 1, 1)
    cores = amostra[candidato]
    matriz = _caracteristicas(x, y)
    valido = np.ones(len(cores), dtype=bool)
    coef = None
    for _ in range(3):
        coef = np.linalg.lstsq(matriz[valido], cores[valido], rcond=None)[0]
        residuo = np.linalg.norm(matriz @ coef - cores, axis=1)
        valido = residuo < 17.0

    x_t = np.arange(largura, dtype=np.float32) / max(largura - 1, 1)
    y_t = np.arange(altura, dtype=np.float32) / max(altura - 1, 1)
    grade_x, grade_y = np.meshgrid(x_t, y_t)
    fundo = (_caracteristicas(grade_x.ravel(), grade_y.ravel()) @ coef).reshape(altura, largura, 3)
    distancia = np.linalg.norm(rgb - fundo, axis=2)
    alfa = np.clip((distancia - 10.0) / 45.0, 0.0, 1.0)

    mascara = (alfa > 0.075).astype(np.uint8)
    numero, rotulos, estatisticas, _ = cv2.connectedComponentsWithStats(mascara, 8)
    manter = np.zeros_like(mascara)
    for indice in range(1, numero):
        if estatisticas[indice, cv2.CC_STAT_AREA] >= 2:
            manter[rotulos == indice] = 1
    alfa *= manter

    a = np.maximum(alfa[..., None], 1.0 / 255.0)
    cor = np.clip((rgb - (1.0 - a) * fundo) / a, 0.0, 255.0)
    saida = np.dstack((cor, alfa[..., None] * 255.0)).astype(np.uint8)
    saida[alfa <= 0.0] = 0
    return Image.fromarray(saida, "RGBA")


def extrair_quadros(folha: Image.Image) -> dict[str, list[Image.Image]]:
    transparente = remover_fundo(folha)
    resultado = {}
    for animacao, dados in ANIMACOES.items():
        y0, y1 = dados["y"]
        faixa = np.asarray(transparente.crop((0, y0, folha.width, y1))).copy()
        mascara = (faixa[..., 3] > 17).astype(np.uint8)
        numero, rotulos, estatisticas, centroides = cv2.connectedComponentsWithStats(mascara, 8)
        resultado[animacao] = []
        for indice, (x0, x1) in enumerate(dados["quadros"]):
            selecao = np.zeros_like(mascara, dtype=bool)
            largura_janela = x1 - x0
            for componente in range(1, numero):
                if estatisticas[componente, cv2.CC_STAT_AREA] < 2:
                    continue
                centro_x, centro_y = centroides[componente]
                if centro_y < 42 and centro_x < 280:
                    continue
                caixa_x = estatisticas[componente, cv2.CC_STAT_LEFT]
                caixa_largura = estatisticas[componente, cv2.CC_STAT_WIDTH]
                caixa_fim = caixa_x + caixa_largura
                ligado_a_outro_quadro = caixa_largura > largura_janela * 1.65
                if ligado_a_outro_quadro and caixa_x < x1 and caixa_fim > x0:
                    parte = rotulos == componente
                    parte[:, :x0] = False
                    parte[:, x1:] = False
                    selecao |= parte
                elif x0 <= centro_x < x1:
                    selecao |= rotulos == componente
            pixels = faixa.copy()
            pixels[~selecao] = 0
            quadro_largo = Image.fromarray(pixels, "RGBA")
            caixa = quadro_largo.getchannel("A").point(lambda a: 255 if a > 17 else 0).getbbox()
            if caixa is None:
                raise RuntimeError(f"quadro vazio: {animacao} {indice}")
            recorte = quadro_largo.crop(caixa)
            base_relativa = int(dados["base"]) - y0 - caixa[1]
            limite_x, limite_y = CELULA[0] - 8, CELULA[1] - 4
            escala = min(1.0, limite_x / recorte.width, limite_y / recorte.height)
            if escala < 1.0:
                recorte = recorte.resize((max(1, round(recorte.width * escala)),
                                          max(1, round(recorte.height * escala))), Image.Resampling.LANCZOS)
                base_relativa = round(base_relativa * escala)
            tela = Image.new("RGBA", CELULA, (0, 0, 0, 0))
            destino_x = (CELULA[0] - recorte.width) // 2
            destino_y = BASE_CELULA - base_relativa
            tela.alpha_composite(recorte, (destino_x, destino_y))
            resultado[animacao].append(tela)
        # A legenda da folha encosta no primeiro desenho em varias faixas JPG.
        # Em vez de furar a criatura tentando separar pixels já fundidos,
        # repete-se o segundo desenho (pose quase identica) no primeiro quadro.
        if len(resultado[animacao]) > 1:
            resultado[animacao][0] = resultado[animacao][1].copy()
    return resultado


def escrever_atlas(quadros: dict[str, list[Image.Image]], destino: Path) -> dict:
    lista = [(animacao, indice, quadro)
             for animacao, imagens in quadros.items()
             for indice, quadro in enumerate(imagens)]
    linhas = (len(lista) + COLUNAS - 1) // COLUNAS
    atlas = Image.new("RGBA", (CELULA[0] * COLUNAS, CELULA[1] * linhas), (0, 0, 0, 0))
    posicoes = {}
    for posicao, (animacao, indice, quadro) in enumerate(lista):
        coluna, linha = posicao % COLUNAS, posicao // COLUNAS
        atlas.alpha_composite(quadro, (coluna * CELULA[0], linha * CELULA[1]))
        posicoes[(animacao, indice)] = (coluna * CELULA[0], linha * CELULA[1])
    destino.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(destino, "WEBP", quality=88, method=4)
    return posicoes


def escrever_sprite_frames(nome: str, quadros: dict[str, list[Image.Image]],
                           posicoes: dict, atlas: Path, destino: Path) -> None:
    caminho_atlas = f"res://textures/ecos/{nome}/atlas.webp"
    subrecursos = []
    ids = {}
    for animacao, imagens in quadros.items():
        for indice in range(len(imagens)):
            ident = f"Atlas_{animacao}_{indice:02d}"
            x, y = posicoes[(animacao, indice)]
            subrecursos.append(
                f'[sub_resource type="AtlasTexture" id="{ident}"]\n'
                'atlas = ExtResource("1_atlas")\n'
                f'region = Rect2({x}, {y}, {CELULA[0]}, {CELULA[1]})')
            ids[(animacao, indice)] = ident

    animacoes = []
    for animacao, imagens in quadros.items():
        frames = ", ".join(
            '{"duration": 1.0, "texture": SubResource("%s")}' % ids[(animacao, i)]
            for i in range(len(imagens)))
        dados = ANIMACOES[animacao]
        animacoes.append(
            '{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}' %
            (frames, "true" if dados["loop"] else "false", animacao, dados["fps"]))

    texto = ('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n\n'
             '[ext_resource type="Texture2D" path="%s" id="1_atlas"]\n\n%s\n\n'
             '[resource]\nanimations = [%s]\n') % (
                 len(subrecursos) + 2, caminho_atlas, "\n\n".join(subrecursos),
                 ", ".join(animacoes))
    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(texto, encoding="utf-8")


def main() -> None:
    if len(sys.argv) == 4 and sys.argv[1] == "--reduzir-existentes":
        texturas, recursos = map(Path, sys.argv[2:])
        quadros_vazios = {nome: [None] * len(dados["quadros"])
                          for nome, dados in ANIMACOES.items()}
        for _, nome in ECOS:
            atlas = texturas / nome / "atlas.webp"
            imagem = Image.open(atlas).convert("RGBA")
            imagem = imagem.resize((CELULA[0] * COLUNAS, CELULA[1] * 9),
                                    Image.Resampling.LANCZOS)
            imagem.save(atlas, "WEBP", quality=88, method=4)
            posicoes = {}
            indice_global = 0
            for animacao, imagens in quadros_vazios.items():
                for indice in range(len(imagens)):
                    coluna, linha = indice_global % COLUNAS, indice_global // COLUNAS
                    posicoes[(animacao, indice)] = (coluna * CELULA[0], linha * CELULA[1])
                    indice_global += 1
            escrever_sprite_frames(nome, quadros_vazios, posicoes, atlas,
                                   recursos / f"eco_{nome}_frames.tres")
            print(f"{nome}: {atlas.stat().st_size / 1024:.1f} KiB")
        return
    if len(sys.argv) != 4:
        raise SystemExit("uso: recortar_ecos_lote.py PASTA_FOTOS PASTA_TEXTURES PASTA_RESOURCES\n"
                         "  ou: recortar_ecos_lote.py --reduzir-existentes PASTA_TEXTURES PASTA_RESOURCES")
    origem, texturas, recursos = map(Path, sys.argv[1:])
    for numero, nome in ECOS:
        folha = origem / f"{numero}-Foto-{numero}.jpg"
        if not folha.exists():
            raise FileNotFoundError(folha)
        quadros = extrair_quadros(Image.open(folha))
        atlas = texturas / nome / "atlas.webp"
        posicoes = escrever_atlas(quadros, atlas)
        recurso = recursos / f"eco_{nome}_frames.tres"
        escrever_sprite_frames(nome, quadros, posicoes, atlas, recurso)
        print(f"{nome}: {atlas.stat().st_size / 1024:.1f} KiB")


if __name__ == "__main__":
    main()
