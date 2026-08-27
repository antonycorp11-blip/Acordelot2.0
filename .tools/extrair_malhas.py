#!/usr/bin/env python3
"""Tira algumas malhas de um GLB grande e escreve um GLB pequeno so com elas.

Os pacotes de vegetacao que chegam do Sketchfab trazem a mesma planta repetida
dezenas de vezes: o `grass_vegitation_mix.glb` tem 65 malhas e 20 MB, mas so
QUATRO formas diferentes — o resto sao copias, cada uma com a propria geometria
no arquivo. Jogar isso inteiro no projeto e pagar 20 MB de download por 0,6 MB
de conteudo, num jogo que a Vercel serve para celular.

Este script guarda uma copia de cada forma pedida, com a matriz de mundo do
node original ja embutida (a cadeia do Sketchfab tem rotacao Z-up e escala de
centimetros; sem isso a planta chega deitada e cem vezes maior).

Uso: extrair_malhas.py entrada.glb saida.glb malha:nome [malha:nome ...]
     onde `malha` e o indice mostrado por glbinfo/`--listar`.
"""
import json
import os
import struct
import sys


def ler(caminho):
    dados = open(caminho, "rb").read()
    tam_json = struct.unpack("<I", dados[12:16])[0]
    cabecalho = json.loads(dados[20:20 + tam_json])
    inicio = 20 + tam_json
    tam_bin = struct.unpack("<I", dados[inicio:inicio + 4])[0]
    binario = dados[inicio + 8:inicio + 8 + tam_bin]
    return cabecalho, binario


def escrever(caminho, cabecalho, binario):
    texto = json.dumps(cabecalho, separators=(",", ":")).encode("utf-8")
    texto += b" " * ((4 - len(texto) % 4) % 4)
    binario += b"\x00" * ((4 - len(binario) % 4) % 4)
    total = 12 + 8 + len(texto) + 8 + len(binario)
    with open(caminho, "wb") as saida:
        saida.write(struct.pack("<III", 0x46546C67, 2, total))
        saida.write(struct.pack("<II", len(texto), 0x4E4F534A))
        saida.write(texto)
        saida.write(struct.pack("<II", len(binario), 0x004E4942))
        saida.write(binario)


def identidade():
    return [1.0 if i % 5 == 0 else 0.0 for i in range(16)]


def multiplicar(a, b):
    """Produto de duas matrizes 4x4 em ordem de coluna, como manda o glTF."""
    fora = [0.0] * 16
    for coluna in range(4):
        for linha in range(4):
            fora[coluna * 4 + linha] = sum(
                a[k * 4 + linha] * b[coluna * 4 + k] for k in range(4))
    return fora


def matriz_do_node(node):
    if "matrix" in node:
        return list(node["matrix"])
    m = identidade()
    escala = node.get("scale", [1.0, 1.0, 1.0])
    if "rotation" in node:
        x, y, z, w = node["rotation"]
        m = [
            1 - 2 * (y * y + z * z), 2 * (x * y + z * w), 2 * (x * z - y * w), 0.0,
            2 * (x * y - z * w), 1 - 2 * (x * x + z * z), 2 * (y * z + x * w), 0.0,
            2 * (x * z + y * w), 2 * (y * z - x * w), 1 - 2 * (x * x + y * y), 0.0,
            0.0, 0.0, 0.0, 1.0]
    for coluna in range(3):
        for linha in range(3):
            m[coluna * 4 + linha] *= escala[coluna]
    t = node.get("translation", [0.0, 0.0, 0.0])
    m[12], m[13], m[14] = t[0], t[1], t[2]
    return m


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 1
    entrada, saida = sys.argv[1], sys.argv[2]
    cabecalho, binario = ler(entrada)

    if sys.argv[3:4] == ["--listar"]:
        for i, malha in enumerate(cabecalho["meshes"]):
            print(i, malha.get("name"))
        return 0

    pedidos = []
    for arg in sys.argv[3:]:
        indice, _, nome = arg.partition(":")
        pedidos.append((int(indice), nome or "malha_%s" % indice))

    # Matriz de mundo de cada node, para achar a da copia que carrega a malha.
    pai = {}
    for i, node in enumerate(cabecalho["nodes"]):
        for filho in node.get("children", []):
            pai[filho] = i

    def mundo(i):
        m = matriz_do_node(cabecalho["nodes"][i])
        while i in pai:
            i = pai[i]
            m = multiplicar(matriz_do_node(cabecalho["nodes"][i]), m)
        return m

    node_da_malha = {}
    for i, node in enumerate(cabecalho["nodes"]):
        if "mesh" in node and node["mesh"] not in node_da_malha:
            node_da_malha[node["mesh"]] = i

    novo = {
        "asset": {"version": "2.0", "generator": "extrair_malhas.py"},
        "scene": 0, "scenes": [{"nodes": []}],
        "nodes": [], "meshes": [], "materials": [], "textures": [],
        "images": [], "samplers": cabecalho.get("samplers", []),
        "accessors": [], "bufferViews": [], "buffers": [],
    }
    pedaco = bytearray()
    mapa_view, mapa_acc, mapa_mat, mapa_tex, mapa_img = {}, {}, {}, {}, {}

    TAM_COMPONENTE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
    QUANTOS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4,
               "MAT2": 4, "MAT3": 9, "MAT4": 16}

    def copiar_view(indice):
        """Copia uma bufferView inteira — so serve para imagem."""
        if indice in mapa_view:
            return mapa_view[indice]
        v = dict(cabecalho["bufferViews"][indice])
        inicio = v.get("byteOffset", 0)
        dados = binario[inicio:inicio + v["byteLength"]]
        while len(pedaco) % 4:
            pedaco.append(0)
        v["byteOffset"] = len(pedaco)
        v["buffer"] = 0
        v.pop("byteStride", None)
        pedaco.extend(dados)
        mapa_view[indice] = len(novo["bufferViews"])
        novo["bufferViews"].append(v)
        return mapa_view[indice]

    def copiar_acc(indice):
        """Recorta SO os elementos deste accessor.

        As malhas do pacote dividem poucas bufferViews gigantes: copiar a view
        inteira trazia os 20 MB do arquivo de volta, uma vez por atributo. Aqui
        o dado sai elemento a elemento, ja desentrelacado e sem passo.
        """
        if indice in mapa_acc:
            return mapa_acc[indice]
        a = dict(cabecalho["accessors"][indice])
        if "bufferView" in a:
            v = cabecalho["bufferViews"][a["bufferView"]]
            largura = TAM_COMPONENTE[a["componentType"]] * QUANTOS[a["type"]]
            passo = v.get("byteStride") or largura
            base = v.get("byteOffset", 0) + a.get("byteOffset", 0)
            while len(pedaco) % 4:
                pedaco.append(0)
            comeco = len(pedaco)
            for k in range(a["count"]):
                inicio = base + k * passo
                pedaco.extend(binario[inicio:inicio + largura])
            a["bufferView"] = len(novo["bufferViews"])
            a.pop("byteOffset", None)
            novo["bufferViews"].append({
                "buffer": 0, "byteOffset": comeco,
                "byteLength": len(pedaco) - comeco})
        mapa_acc[indice] = len(novo["accessors"])
        novo["accessors"].append(a)
        return mapa_acc[indice]

    def copiar_img(indice):
        if indice in mapa_img:
            return mapa_img[indice]
        im = dict(cabecalho["images"][indice])
        if "bufferView" in im:
            im["bufferView"] = copiar_view(im["bufferView"])
        mapa_img[indice] = len(novo["images"])
        novo["images"].append(im)
        return mapa_img[indice]

    def copiar_tex(indice):
        if indice in mapa_tex:
            return mapa_tex[indice]
        t = dict(cabecalho["textures"][indice])
        if "source" in t:
            t["source"] = copiar_img(t["source"])
        mapa_tex[indice] = len(novo["textures"])
        novo["textures"].append(t)
        return mapa_tex[indice]

    def copiar_mat(indice):
        if indice in mapa_mat:
            return mapa_mat[indice]
        m = json.loads(json.dumps(cabecalho["materials"][indice]))
        pbr = m.get("pbrMetallicRoughness", {})
        for chave in ("baseColorTexture", "metallicRoughnessTexture"):
            if chave in pbr:
                pbr[chave]["index"] = copiar_tex(pbr[chave]["index"])
        for chave in ("normalTexture", "occlusionTexture", "emissiveTexture"):
            if chave in m:
                m[chave]["index"] = copiar_tex(m[chave]["index"])
        mapa_mat[indice] = len(novo["materials"])
        novo["materials"].append(m)
        return mapa_mat[indice]

    for indice, nome in pedidos:
        malha = json.loads(json.dumps(cabecalho["meshes"][indice]))
        malha["name"] = nome
        for prim in malha["primitives"]:
            prim["attributes"] = {
                k: copiar_acc(v) for k, v in prim["attributes"].items()}
            if "indices" in prim:
                prim["indices"] = copiar_acc(prim["indices"])
            if "material" in prim:
                prim["material"] = copiar_mat(prim["material"])
        novo["scenes"][0]["nodes"].append(len(novo["nodes"]))
        novo["nodes"].append({
            "name": nome,
            "mesh": len(novo["meshes"]),
            "matrix": mundo(node_da_malha[indice]),
        })
        novo["meshes"].append(malha)

    novo["buffers"].append({"byteLength": len(pedaco)})
    if not novo["samplers"]:
        novo.pop("samplers")
    escrever(saida, novo, bytes(pedaco))
    print("%s -> %s (%.2f MB)" % (
        os.path.basename(entrada), saida, os.path.getsize(saida) / 1e6))
    return 0


if __name__ == "__main__":
    sys.exit(main())
