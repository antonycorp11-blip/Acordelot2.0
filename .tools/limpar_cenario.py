#!/usr/bin/env python3
"""Tira o cenario que vem junto de um modelo de personagem.

Modelo baixado costuma vir montado numa cena: o dragao traz um plano de chao
embaixo dele, porque foi assim que o autor apresentou o trabalho. Dentro do
jogo isso e uma placa gigante flutuando sobre o terreno de verdade.

E o mesmo remendo resolve um segundo defeito: quando o plano vem SEM primitiva
nenhuma, o arquivo deixa de ser glTF valido e o Godot recusa o modelo inteiro —
o dragao simplesmente nao aparecia.

Uso: limpar_cenario.py arquivo.glb [arquivo.glb ...]
"""
import json
import os
import struct
import sys

# Nomes que autores usam para o chao de apresentacao.
#
# A comparacao e por PALAVRA INTEIRA, nunca por pedaco: "plane" dentro de
# "leafplanes" e folha de arvore, e um filtro por substring apagou as 195 folhas
# de um carvalho antes de esta linha existir.
CENARIO = ("plane", "ground", "floor", "base", "terrain", "chao", "piso",
           "groundplane", "baseplane")


def _ler(caminho):
    dados = open(caminho, "rb").read()
    tamanho = struct.unpack("<I", dados[12:16])[0]
    cabecalho = json.loads(dados[20:20 + tamanho])
    inicio = 20 + tamanho
    corpo = struct.unpack("<I", dados[inicio:inicio + 4])[0]
    return cabecalho, dados[inicio + 8:inicio + 8 + corpo]


def _gravar(caminho, cabecalho, binario):
    texto = json.dumps(cabecalho, separators=(",", ":")).encode()
    texto += b" " * ((4 - len(texto) % 4) % 4)
    binario += b"\0" * ((4 - len(binario) % 4) % 4)
    corpo = (struct.pack("<I", len(texto)) + b"JSON" + texto
             + struct.pack("<I", len(binario)) + b"BIN\0" + binario)
    open(caminho, "wb").write(
        struct.pack("<III", 0x46546C67, 2, 12 + len(corpo)) + corpo)


def limpar(caminho):
    cabecalho, binario = _ler(caminho)
    malhas = cabecalho.get("meshes", [])

    # Fora: a que se chama de chao, e a que nao tem geometria nenhuma. A segunda
    # sozinha ja invalida o arquivo para o importador.
    descartar = set()
    for indice, malha in enumerate(malhas):
        nome = str(malha.get("name", "")).lower()
        vazia = not malha.get("primitives")
        # Separa o nome em palavras: Blender exporta como "Plane_Material_0",
        # entao o que interessa e o primeiro pedaco antes do sublinhado.
        var_pedacos = [t for t in nome.replace(".", "_").split("_") if t]
        se_chama_chao = bool(var_pedacos) and var_pedacos[0] in CENARIO
        if vazia or se_chama_chao:
            descartar.add(indice)

    if not descartar:
        return 0, [m.get("name", "?") for m in malhas]

    # Remover embaralha os indices, entao guarda-se o novo lugar de cada uma que
    # fica; quem apontava para uma descartada perde a referencia e vira no vazio.
    novo_lugar = {}
    restantes = []
    for indice, malha in enumerate(malhas):
        if indice in descartar:
            continue
        novo_lugar[indice] = len(restantes)
        restantes.append(malha)

    for no in cabecalho.get("nodes", []):
        if "mesh" not in no:
            continue
        if no["mesh"] in novo_lugar:
            no["mesh"] = novo_lugar[no["mesh"]]
        else:
            del no["mesh"]

    cabecalho["meshes"] = restantes
    _gravar(caminho, cabecalho, binario)
    return len(descartar), [malhas[i].get("name", "?") for i in sorted(descartar)]


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return
    for caminho in sys.argv[1:]:
        if not os.path.exists(caminho):
            print(f"{os.path.basename(caminho):28} nao encontrado")
            continue
        quantas, nomes = limpar(caminho)
        nome = os.path.basename(caminho)
        if quantas == 0:
            print(f"{nome:28} nada a tirar")
        else:
            print(f"{nome:28} removidas {quantas}: {', '.join(nomes)}")


main()
