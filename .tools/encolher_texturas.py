#!/usr/bin/env python3
"""Reduz as texturas embutidas de um GLB.

O decimador ao lado resolve geometria e nao toca em imagem — e nestes modelos a
imagem E o arquivo: 70 pedras de cinco mil triangulos pesam 65 MB porque cada
uma traz a propria textura em 2K. Num jogo visto de cima, onde a pedra ocupa
quarenta pixels da tela, 2K e desperdicio puro de download e de memoria de
video.

Uso: encolher_texturas.py [lado_maximo] arquivo.glb [arquivo.glb ...]
"""
import io
import json
import os
import struct
import sys

from PIL import Image

LADO_PADRAO = 512
# Abaixo disto nao vale reprocessar: o ganho nao paga a perda de nitidez.
MENOR_QUE_VALE = 4096


def _ler(caminho):
    dados = open(caminho, "rb").read()
    tamanho_json = struct.unpack("<I", dados[12:16])[0]
    cabecalho = json.loads(dados[20:20 + tamanho_json])
    inicio_bin = 20 + tamanho_json
    tamanho_bin = struct.unpack("<I", dados[inicio_bin:inicio_bin + 4])[0]
    binario = dados[inicio_bin + 8:inicio_bin + 8 + tamanho_bin]
    return cabecalho, bytearray(binario)


def _gravar(caminho, cabecalho, binario):
    # O glTF exige que os dois blocos terminem em multiplo de quatro; sem o
    # enchimento, quem for ler depois encontra o cabecalho no lugar errado.
    texto = json.dumps(cabecalho, separators=(",", ":")).encode()
    texto += b" " * ((4 - len(texto) % 4) % 4)
    binario += b"\0" * ((4 - len(binario) % 4) % 4)

    corpo = (struct.pack("<I", len(texto)) + b"JSON" + texto
             + struct.pack("<I", len(binario)) + b"BIN\0" + bytes(binario))
    open(caminho, "wb").write(
        struct.pack("<III", 0x46546C67, 2, 12 + len(corpo)) + corpo)


def encolher(caminho, saida, lado):
    cabecalho, binario = _ler(caminho)
    vistas = cabecalho.get("bufferViews", [])
    imagens = cabecalho.get("images", [])
    if not imagens:
        return 0, 0

    # As imagens sao reconstruidas em sequencia num binario NOVO, e nao trocadas
    # no lugar: elas encolhem, e escrever por cima deixaria buracos que os
    # deslocamentos das outras vistas ja nao apontam mais.
    novo_binario = bytearray()
    remapeamento = {}

    for indice, imagem in enumerate(imagens):
        if "bufferView" not in imagem:
            continue
        vista = vistas[imagem["bufferView"]]
        inicio = vista.get("byteOffset", 0)
        bruto = bytes(binario[inicio:inicio + vista["byteLength"]])

        try:
            figura = Image.open(io.BytesIO(bruto))
            figura.load()
        except Exception:
            remapeamento[imagem["bufferView"]] = bruto
            continue

        if max(figura.size) > lado:
            escala = lado / max(figura.size)
            figura = figura.resize(
                (max(1, int(figura.size[0] * escala)),
                 max(1, int(figura.size[1] * escala))), Image.LANCZOS)

        buffer = io.BytesIO()
        if figura.mode in ("RGBA", "LA", "P"):
            figura.convert("RGBA").save(buffer, "PNG", optimize=True)
            imagem["mimeType"] = "image/png"
        else:
            figura.convert("RGB").save(buffer, "JPEG", quality=82, optimize=True)
            imagem["mimeType"] = "image/jpeg"
        remapeamento[imagem["bufferView"]] = buffer.getvalue()

    # Reescreve TODAS as vistas: as de imagem com o dado novo, as de geometria
    # copiadas como estao, cada uma recebendo o seu deslocamento atualizado.
    for indice, vista in enumerate(vistas):
        if indice in remapeamento:
            conteudo = remapeamento[indice]
        else:
            inicio = vista.get("byteOffset", 0)
            conteudo = bytes(binario[inicio:inicio + vista["byteLength"]])
        # Acessor de geometria exige alinhamento de quatro bytes.
        while len(novo_binario) % 4:
            novo_binario.append(0)
        vista["byteOffset"] = len(novo_binario)
        vista["byteLength"] = len(conteudo)
        novo_binario += conteudo

    cabecalho["buffers"] = [{"byteLength": len(novo_binario)}]
    _gravar(saida, cabecalho, novo_binario)
    return os.path.getsize(caminho), os.path.getsize(saida)


def main():
    argumentos = sys.argv[1:]
    lado = LADO_PADRAO
    if argumentos and argumentos[0].isdigit():
        lado = int(argumentos.pop(0))
    if not argumentos:
        print(__doc__)
        return

    for caminho in argumentos:
        nome = os.path.basename(caminho)
        saida = os.path.join("models", nome)
        antes, depois = encolher(caminho, saida, lado)
        if antes == 0:
            print(f"{nome:38} sem textura embutida")
            continue
        print(f"{nome:38} {antes / 1048576:6.1f} MB -> {depois / 1048576:5.1f} MB")


main()
