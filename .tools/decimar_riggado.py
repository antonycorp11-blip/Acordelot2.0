#!/usr/bin/env python3
"""Decima um GLB RIGGADO mantendo textura, ossos e pesos.

O `decimar_malha.py` existe para os cenarios do TripoSR: malhas de posicao e cor
por vertice, sem UV e sem esqueleto. Passar um personagem por ele apaga a
coordenada de textura e a pele — o modelo volta cinza e sem rig, que e o oposto
do que se quer num chefe.

Aqui a decimacao e a mesma (colapso de aresta com metrica quadrica, que preserva
silhueta), mas TODO o resto viaja junto:

- TEXCOORD_0, JOINTS_0 e WEIGHTS_0 vao pelo REPRESENTANTE, nao pela media. Media
  de coordenada de textura borra a costura do mapa; media de indice de osso nao
  significa nada — a media entre o osso 3 e o 17 nao e o osso 10.
- Os nos do esqueleto, o `skin` e as matrizes de bind sao copiados sem tocar.
- As imagens saem do buffer antigo e entram no novo sem recompressao.

Uso: decimar_riggado.py <entrada.glb> <saida.glb> [alvo_de_triangulos]
"""
import json, struct, sys
import numpy as np
import fast_simplification
from fast_simplification.replay import replay_simplification

TIPOS = {5120: "i1", 5121: "u1", 5122: "i2", 5123: "u2", 5125: "u4", 5126: "f4"}
LARGURAS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def abrir(caminho):
    d = open(caminho, "rb").read()
    o = 12
    cl, _ = struct.unpack("<II", d[o:o + 8])
    js = json.loads(d[o + 8:o + 8 + cl])
    o += 8 + cl
    bl, _ = struct.unpack("<II", d[o:o + 8])
    return js, d[o + 8:o + 8 + bl]


def ler(js, blob, indice):
    a = js["accessors"][indice]
    v = js["bufferViews"][a["bufferView"]]
    largura = LARGURAS[a["type"]]
    dt = np.dtype("<" + TIPOS[a["componentType"]])
    inicio = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    passo = v.get("byteStride") or (dt.itemsize * largura)
    if passo == dt.itemsize * largura:
        return np.frombuffer(blob, dtype=dt, count=a["count"] * largura,
                             offset=inicio).reshape(a["count"], largura)
    linhas = [np.frombuffer(blob, dtype=dt, count=largura, offset=inicio + i * passo)
              for i in range(a["count"])]
    return np.array(linhas)


def bytes_da_vista(js, blob, indice_da_vista):
    v = js["bufferViews"][indice_da_vista]
    ini = v.get("byteOffset", 0)
    return blob[ini:ini + v["byteLength"]]


def alinhar(dados):
    resto = len(dados) % 4
    return dados + b"\x00" * (4 - resto) if resto else dados


def main():
    entrada, saida = sys.argv[1], sys.argv[2]
    alvo = int(sys.argv[3]) if len(sys.argv) > 3 else 30000
    js, blob = abrir(entrada)
    prim = js["meshes"][0]["primitives"][0]
    attrs = prim["attributes"]

    pos = ler(js, blob, attrs["POSITION"]).astype(np.float32)
    idx = ler(js, blob, prim["indices"]).reshape(-1, 3).astype(np.int32)
    print("entrada: %d vertices  %d triangulos" % (len(pos), len(idx)))

    reducao = 1.0 - min(1.0, alvo / float(len(idx)))
    _, _, colapsos = fast_simplification.simplify(
        pos, idx, reducao, return_collapses=True)
    nova_pos, novos_tri, mapa = replay_simplification(pos, idx, colapsos)
    nova_pos = np.asarray(nova_pos, dtype=np.float32)
    novos_tri = np.asarray(novos_tri, dtype=np.uint32)
    mapa = np.asarray(mapa)
    print("saida:   %d vertices  %d triangulos  (%.2f%% do original)"
          % (len(nova_pos), len(novos_tri), 100.0 * len(novos_tri) / len(idx)))

    # O REPRESENTANTE DE CADA VERTICE NOVO: o primeiro original que desaguou
    # nele. E o que preserva UV e pele sem inventar valor intermediario.
    representante = np.full(len(nova_pos), -1, dtype=np.int64)
    valido = mapa >= 0
    originais = np.nonzero(valido)[0]
    # Preenche de tras para frente: o menor indice original fica por ultimo e
    # sobrescreve, entao vence o primeiro.
    representante[mapa[originais[::-1]]] = originais[::-1]
    faltando = representante < 0
    if faltando.any():
        representante[faltando] = 0
        print("  aviso: %d vertices sem representante" % int(faltando.sum()))

    novos_attrs = {"POSITION": ("VEC3", 5126, nova_pos)}
    for nome, tipo in (("NORMAL", "VEC3"), ("TEXCOORD_0", "VEC2"),
                       ("JOINTS_0", "VEC4"), ("WEIGHTS_0", "VEC4")):
        if nome not in attrs:
            continue
        a = js["accessors"][attrs[nome]]
        dados = ler(js, blob, attrs[nome])[representante]
        novos_attrs[nome] = (tipo, a["componentType"], dados)
        print("  guardado %s (%s)" % (nome, a["componentType"]))

    # Normal recalculada: depois do colapso a antiga aponta para a superficie
    # que nao existe mais e a luz fica manchada.
    if "NORMAL" in novos_attrs:
        n = np.zeros_like(nova_pos, dtype=np.float64)
        t = novos_tri.astype(np.int64)
        face = np.cross(nova_pos[t[:, 1]] - nova_pos[t[:, 0]],
                        nova_pos[t[:, 2]] - nova_pos[t[:, 0]])
        for canto in range(3):
            np.add.at(n, t[:, canto], face)
        tam = np.linalg.norm(n, axis=1, keepdims=True)
        tam[tam == 0] = 1.0
        novos_attrs["NORMAL"] = ("VEC3", 5126, (n / tam).astype(np.float32))

    blocos, vistas, acessores = [], [], []
    desloc = 0

    def guardar(dados_bytes, alvo_gl=None):
        nonlocal desloc
        v = {"buffer": 0, "byteOffset": desloc, "byteLength": len(dados_bytes)}
        if alvo_gl:
            v["target"] = alvo_gl
        vistas.append(v)
        cheio = alinhar(dados_bytes)
        blocos.append(cheio)
        desloc += len(cheio)
        return len(vistas) - 1

    mapa_attrs = {}
    for nome, (tipo, comp, dados) in novos_attrs.items():
        dt = np.dtype("<" + TIPOS[comp])
        vista = guardar(dados.astype(dt).tobytes(), 34962)
        ac = {"bufferView": vista, "componentType": comp, "count": len(dados),
              "type": tipo}
        if nome == "POSITION":
            ac["min"] = dados.min(axis=0).tolist()
            ac["max"] = dados.max(axis=0).tolist()
        acessores.append(ac)
        mapa_attrs[nome] = len(acessores) - 1

    vista_idx = guardar(novos_tri.ravel().astype("<u4").tobytes(), 34963)
    acessores.append({"bufferView": vista_idx, "componentType": 5125,
                      "count": int(novos_tri.size), "type": "SCALAR"})
    indice_dos_triangulos = len(acessores) - 1

    novo = {
        "asset": js["asset"], "scene": js.get("scene", 0),
        "scenes": js["scenes"], "nodes": js["nodes"],
        "materials": js.get("materials", []), "samplers": js.get("samplers", []),
        "meshes": [{"name": js["meshes"][0].get("name", "malha"), "primitives": [{
            "attributes": mapa_attrs, "indices": indice_dos_triangulos,
            "material": prim.get("material", 0), "mode": 4}]}],
    }

    if "skins" in js:
        pele = dict(js["skins"][0])
        if "inverseBindMatrices" in pele:
            a = js["accessors"][pele["inverseBindMatrices"]]
            vista = guardar(bytes_da_vista(js, blob, a["bufferView"]))
            acessores.append({"bufferView": vista, "componentType": a["componentType"],
                              "count": a["count"], "type": a["type"]})
            pele["inverseBindMatrices"] = len(acessores) - 1
        novo["skins"] = [pele]
        print("  esqueleto preservado: %d ossos" % len(pele.get("joints", [])))

    if "images" in js:
        imagens, texturas = [], js.get("textures", [])
        for img in js["images"]:
            vista = guardar(bytes_da_vista(js, blob, img["bufferView"]))
            imagens.append({"name": img.get("name", ""), "mimeType": img["mimeType"],
                            "bufferView": vista})
        novo["images"] = imagens
        novo["textures"] = texturas
        print("  %d texturas preservadas" % len(imagens))

    novo["accessors"] = acessores
    novo["bufferViews"] = vistas
    binario = b"".join(blocos)
    novo["buffers"] = [{"byteLength": len(binario)}]

    js_bytes = json.dumps(novo, separators=(",", ":")).encode("utf-8")
    js_bytes += b" " * ((4 - len(js_bytes) % 4) % 4)
    total = 12 + 8 + len(js_bytes) + 8 + len(binario)
    with open(saida, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, total))
        f.write(struct.pack("<II", len(js_bytes), 0x4E4F534A)); f.write(js_bytes)
        f.write(struct.pack("<II", len(binario), 0x004E4942)); f.write(binario)
    import os
    print("gravado: %s  (%.1f MB, era %.1f MB)"
          % (saida, os.path.getsize(saida) / 1e6, os.path.getsize(entrada) / 1e6))


if __name__ == "__main__":
    main()
