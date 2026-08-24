#!/usr/bin/env python3
"""Separa as duas pranchas de notas e remove o fundo magenta.

Gera PNGs quadrados transparentes para a interface e uma copia com os mesmos
nomes na entrada do TripoSR. A prancha rustica e a dos fragmentos; a prancha
com o simbolo luminoso e a das notas ja sintetizadas.
"""

from pathlib import Path
import random
import sys

from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageStat


ALTURAS = (
    "do", "do_sustenido", "re", "re_sustenido", "mi", "fa",
    "fa_sustenido", "sol", "sol_sustenido", "la", "la_sustenido", "si",
)


def fundo_da_celula(imagem: Image.Image) -> tuple[int, int, int]:
    amostra = Image.new("RGB", (4, 1))
    pontos = (
        imagem.getpixel((2, 2)),
        imagem.getpixel((imagem.width - 3, 2)),
        imagem.getpixel((2, imagem.height - 3)),
        imagem.getpixel((imagem.width - 3, imagem.height - 3)),
    )
    for indice, cor in enumerate(pontos):
        amostra.putpixel((indice, 0), cor[:3])
    mediana = ImageStat.Stat(amostra).median
    return tuple(int(v) for v in mediana[:3])


def tirar_magenta(imagem: Image.Image) -> Image.Image:
    rgb = imagem.convert("RGB")
    fundo = fundo_da_celula(rgb)
    pixels = list(rgb.getdata())
    saida = []
    for r, g, b in pixels:
        distancia = ((r - fundo[0]) ** 2 + (g - fundo[1]) ** 2 + (b - fundo[2]) ** 2) ** 0.5
        # O PNG tem compressao/antialias. A faixa suave tira o halo rosa sem
        # recortar os cristais rosa, que estao muito mais longe da cor do fundo.
        alfa = int(max(0.0, min(1.0, (distancia - 20.0) / 58.0)) * 255.0)
        if alfa == 0:
            saida.append((0, 0, 0, 0))
            continue
        a = alfa / 255.0
        # Descontamina a borda: recupera a cor anterior a mistura com o fundo.
        rr = int(max(0, min(255, (r - (1.0 - a) * fundo[0]) / a)))
        gg = int(max(0, min(255, (g - (1.0 - a) * fundo[1]) / a)))
        bb = int(max(0, min(255, (b - (1.0 - a) * fundo[2]) / a)))
        saida.append((rr, gg, bb, alfa))
    rgba = Image.new("RGBA", rgb.size)
    rgba.putdata(saida)
    caixa = rgba.getchannel("A").getbbox()
    if caixa:
        rgba = rgba.crop(caixa)
    return rgba


def quadrado(item: Image.Image, tamanho: int = 512) -> Image.Image:
    margem = 26
    limite = tamanho - margem * 2
    escala = min(limite / item.width, limite / item.height)
    novo = item.resize(
        (max(1, round(item.width * escala)), max(1, round(item.height * escala))),
        Image.Resampling.LANCZOS,
    )
    tela = Image.new("RGBA", (tamanho, tamanho), (0, 0, 0, 0))
    tela.alpha_composite(novo, ((tamanho - novo.width) // 2, (tamanho - novo.height) // 2))
    return tela


def separar(prancha: Path, prefixo: str, colunas: int, linhas: int,
            alturas_uteis: tuple[float, ...], destino: Path, entrada_tripo: Path) -> None:
    imagem = Image.open(prancha).convert("RGB")
    largura = imagem.width / colunas
    altura = imagem.height / linhas
    for indice, nome in enumerate(ALTURAS):
        coluna = indice % colunas
        linha = indice // colunas
        x0 = round(coluna * largura)
        x1 = round((coluna + 1) * largura)
        y0 = round(linha * altura)
        y1 = round(y0 + altura * alturas_uteis[min(linha, len(alturas_uteis) - 1)])
        item_tripo = quadrado(tirar_magenta(imagem.crop((x0, y0, x1, y1))), 512)
        item_ui = item_tripo.resize((256, 256), Image.Resampling.LANCZOS)
        arquivo = f"{prefixo}_{nome}.png"
        item_ui.save(destino / arquivo, optimize=True)
        item_tripo.save(entrada_tripo / arquivo, optimize=True)
        print(arquivo)


def criar_corrompidos(destino: Path) -> None:
    """Preserva a cor natural e sinaliza corrupcao so com particulas roxas."""
    for nome in ALTURAS:
        base = Image.open(destino / f"fragmento_{nome}.png").convert("RGBA")
        alfa = base.getchannel("A")

        largura, altura = base.size
        particulas = Image.new("RGBA", base.size, (0, 0, 0, 0))
        nucleos = Image.new("RGBA", base.size, (0, 0, 0, 0))
        desenho = ImageDraw.Draw(particulas)
        desenho_nucleos = ImageDraw.Draw(nucleos)
        rng = random.Random(nome)
        for _ in range(11):
            x = rng.randint(round(largura * 0.18), round(largura * 0.82))
            y = rng.randint(round(altura * 0.12), round(altura * 0.88))
            raio = rng.randint(2, 5)
            desenho.ellipse((x - raio * 3, y - raio * 3, x + raio * 3, y + raio * 3),
                            fill=(122, 36, 232, 150))
            desenho_nucleos.ellipse((x - raio, y - raio, x + raio, y + raio),
                                    fill=(224, 156, 255, 230))
        particulas = particulas.filter(ImageFilter.GaussianBlur(4))

        saida = Image.new("RGBA", base.size, (0, 0, 0, 0))
        saida.alpha_composite(base)
        saida.alpha_composite(particulas)
        saida.alpha_composite(nucleos)
        arquivo = destino / f"fragmento_corrompido_{nome}.png"
        saida.save(arquivo, optimize=True)
        print(arquivo.name)


def main() -> None:
    if len(sys.argv) == 3 and sys.argv[1] == "--somente-corrompidos":
        criar_corrompidos(Path(sys.argv[2]))
        return
    if len(sys.argv) != 5:
        raise SystemExit("uso: recortar_notas.py FRAGMENTOS.png NOTAS.png DESTINO INPUT_TRIPO\n"
                         "  ou: recortar_notas.py --somente-corrompidos DESTINO")
    fragmentos, notas, destino, entrada_tripo = map(Path, sys.argv[1:])
    destino.mkdir(parents=True, exist_ok=True)
    entrada_tripo.mkdir(parents=True, exist_ok=True)
    separar(fragmentos, "fragmento", 4, 3, (1.0,), destino, entrada_tripo)
    criar_corrompidos(destino)
    # A parte inferior de cada celula contem apenas a placa C/C#/...; o icone
    # funcional usa o cristal, enquanto a ordem da grade preserva a identificacao.
    separar(notas, "nota", 6, 2, (0.84, 0.76), destino, entrada_tripo)


if __name__ == "__main__":
    main()
