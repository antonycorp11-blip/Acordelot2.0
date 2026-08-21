#!/usr/bin/env python3
"""Tira o metal de modelos que chegaram em specGloss.

O GLB exportado com KHR_materials_pbrSpecularGlossiness traz, no bloco padrao
que o Godot 4 le, metallicFactor = 1 e nenhum mapa de metal. Metal puro sem
reflexo do ambiente nao devolve luz nenhuma: a casa aparece PRETA, com a
textura carregada e tudo. Foi o que aconteceu com as duas casas de enxaimel.

O conserto e um numero por material: metal a zero, aspereza alta. A imagem de
cor ja esta apontada em baseColorTexture, entao nao ha nada a reconstruir.

Uso: consertar_metalico.py arquivo.glb [arquivo.glb ...]
"""
import json
import os
import struct
import sys


def _ler(caminho):
    dados = open(caminho, "rb").read()
    n = struct.unpack("<I", dados[12:16])[0]
    cabecalho = json.loads(dados[20:20 + n])
    inicio = 20 + n
    tam = struct.unpack("<I", dados[inicio:inicio + 4])[0]
    return cabecalho, dados[inicio + 8:inicio + 8 + tam]


def _gravar(caminho, cabecalho, binario):
    texto = json.dumps(cabecalho, separators=(",", ":")).encode()
    texto += b" " * ((4 - len(texto) % 4) % 4)
    binario += b"\0" * ((4 - len(binario) % 4) % 4)
    with open(caminho, "wb") as arquivo:
        arquivo.write(b"glTF" + struct.pack("<II", 2, 12 + 8 + len(texto) + 8 + len(binario)))
        arquivo.write(struct.pack("<I", len(texto)) + b"JSON" + texto)
        arquivo.write(struct.pack("<I", len(binario)) + b"BIN\0" + binario)


EXT = "KHR_materials_pbrSpecularGlossiness"


def consertar(caminho):
    cabecalho, binario = _ler(caminho)
    tocados = 0
    for material in cabecalho.get("materials", []):
        pbr = material.setdefault("pbrMetallicRoughness", {})

        # A extensao TEM DE SAIR, nao basta corrigir o bloco padrao ao lado.
        #
        # Enquanto ela esta la o Godot 4 le a extensao e ignora o que se
        # escreveu em pbrMetallicRoughness: a conversao que ele faz de
        # specular/glossiness devolve metal 1, aspereza 1 — metal puro, que sem
        # reflexo do ambiente nao acende um pixel. Foi por isso que a primeira
        # tentativa de conserto nao mudou nada na tela.
        #
        # A imagem de cor da extensao vira a cor base, que e a unica coisa dela
        # que valia alguma coisa aqui.
        extensoes = material.get("extensions", {})
        if EXT in extensoes:
            difusa = extensoes[EXT].get("diffuseTexture")
            if difusa is not None and "baseColorTexture" not in pbr:
                pbr["baseColorTexture"] = difusa
            del extensoes[EXT]
            if not extensoes:
                material.pop("extensions", None)
            tocados += 1
        # So mexe em quem NAO tem mapa de metal: quem tem sabe o que faz.
        if "metallicRoughnessTexture" in pbr:
            continue
        if pbr.get("metallicFactor", 1.0) == 0.0:
            continue
        pbr["metallicFactor"] = 0.0
        pbr["roughnessFactor"] = 0.85
        tocados += 1
    for lista in ("extensionsUsed", "extensionsRequired"):
        if EXT in cabecalho.get(lista, []):
            cabecalho[lista] = [e for e in cabecalho[lista] if e != EXT]
            if not cabecalho[lista]:
                del cabecalho[lista]

    if tocados:
        _gravar(caminho, cabecalho, binario)
    print(f"{os.path.basename(caminho):32} {tocados} materiais consertados")


for arquivo_glb in sys.argv[1:]:
    consertar(arquivo_glb)
