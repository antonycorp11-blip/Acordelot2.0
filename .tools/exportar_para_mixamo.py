#!/usr/bin/env python3
"""Tira do GLB o que o Mixamo precisa para riggar: OBJ e FBX ASCII.

O Mixamo nao le GLB. E ele NAO precisa do esqueleto — o proprio servico riga do
zero a partir da malha em pose T ou A, que e exatamente como o modelo do Tripo
vem. Entao aqui sai so geometria, normal e coordenada de textura; o rig do Tripo
fica para tras de proposito, porque o que volta e um rig `mixamorig_*` — o mesmo
que o Akles e a Wins usam, o que deixa o chefe compartilhar animacao com eles.

Sai um ZIP com OBJ, MTL e as tres texturas.

TENTEI ESCREVER FBX E NAO DEU. O dialeto ASCII do FBX tem exigencias que nao se
descobrem lendo o formato de fora — o arquivo que escrevi a mao foi recusado
pelo leitor com "ufbx: Failed to load". Sem uma biblioteca de exportacao (o
Blender, na pratica) nao ha como garantir um FBX valido, e entregar um arquivo
que talvez abra seria pior que entregar um que abre.

O Mixamo aceita OBJ e ZIP do mesmo jeito que aceita FBX, e a malha em pose T
com UV e o suficiente para ele riggar. O que volta de la ja e FBX de verdade.

Uso: exportar_para_mixamo.py <entrada.glb> <pasta_de_saida> [nome]
"""
import json, os, struct, sys, zipfile
import numpy as np

TIPOS = {5120: "i1", 5121: "u1", 5122: "i2", 5123: "u2", 5125: "u4", 5126: "f4"}
LARG = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def abrir(caminho):
    d = open(caminho, "rb").read()
    o = 12
    cl, _ = struct.unpack("<II", d[o:o + 8])
    js = json.loads(d[o + 8:o + 8 + cl])
    o += 8 + cl
    bl, _ = struct.unpack("<II", d[o:o + 8])
    return js, d[o + 8:o + 8 + bl]


def ler(js, blob, i):
    a = js["accessors"][i]
    v = js["bufferViews"][a["bufferView"]]
    dt = np.dtype("<" + TIPOS[a["componentType"]])
    w = LARG[a["type"]]
    ini = v.get("byteOffset", 0) + a.get("byteOffset", 0)
    return np.frombuffer(blob, dtype=dt, count=a["count"] * w,
                         offset=ini).reshape(a["count"], w)


def escrever_obj(pasta, nome, pos, uv, nor, idx, texturas):
    with open(os.path.join(pasta, nome + ".mtl"), "w") as f:
        f.write("newmtl %s\nKa 1 1 1\nKd 1 1 1\nKs 0 0 0\nd 1\nillum 2\n" % nome)
        if "basecolor" in texturas:
            f.write("map_Kd %s\n" % texturas["basecolor"])
        if "normal" in texturas:
            f.write("map_Bump %s\n" % texturas["normal"])
    with open(os.path.join(pasta, nome + ".obj"), "w") as f:
        f.write("# %s — malha para o Mixamo riggar\n" % nome)
        f.write("mtllib %s.mtl\no %s\nusemtl %s\n" % (nome, nome, nome))
        np.savetxt(f, pos, fmt="v %.6f %.6f %.6f")
        vt = uv.copy()
        # O glTF conta o V de cima para baixo; o OBJ, de baixo para cima.
        vt[:, 1] = 1.0 - vt[:, 1]
        np.savetxt(f, vt, fmt="vt %.6f %.6f")
        np.savetxt(f, nor, fmt="vn %.6f %.6f %.6f")
        um = idx + 1
        np.savetxt(f, np.column_stack([um[:, 0], um[:, 0], um[:, 0],
                                       um[:, 1], um[:, 1], um[:, 1],
                                       um[:, 2], um[:, 2], um[:, 2]]),
                   fmt="f %d/%d/%d %d/%d/%d %d/%d/%d")


def escrever_fbx(pasta, nome, pos, uv, nor, idx):
    """FBX 7.3 em ASCII, so com o que descreve uma malha.

    O ultimo indice de cada poligono vai NEGADO E DESLOCADO (~i): e assim que o
    FBX marca o fim de uma face, e sem isso o arquivo inteiro le como um poligono
    so de trinta mil lados.
    """
    caminho = os.path.join(pasta, nome + ".fbx")
    faces = idx.copy()
    plana = np.empty(faces.size, dtype=np.int64)
    plana[0::3] = faces[:, 0]
    plana[1::3] = faces[:, 1]
    plana[2::3] = ~faces[:, 2]

    def lista(v, por_linha=6, casas=6):
        saida, linha = [], []
        forma = "%.*f" % (casas, 0)
        for k, x in enumerate(v):
            linha.append(("%." + str(casas) + "f") % x if casas else str(int(x)))
            if len(linha) == por_linha:
                saida.append(",".join(linha)); linha = []
        if linha:
            saida.append(",".join(linha))
        return "\n\t\t\t\t".join(saida)

    with open(caminho, "w") as f:
        f.write("; FBX 7.3.0 project file\n\nFBXHeaderExtension:  {\n"
                "\tFBXHeaderVersion: 1003\n\tFBXVersion: 7300\n\tCreator: \"AcordeLot\"\n}\n")
        f.write("GlobalSettings:  {\n\tVersion: 1000\n\tProperties70:  {\n"
                "\t\tP: \"UpAxis\", \"int\", \"Integer\", \"\",1\n"
                "\t\tP: \"UpAxisSign\", \"int\", \"Integer\", \"\",1\n"
                "\t\tP: \"FrontAxis\", \"int\", \"Integer\", \"\",2\n"
                "\t\tP: \"FrontAxisSign\", \"int\", \"Integer\", \"\",1\n"
                "\t\tP: \"CoordAxis\", \"int\", \"Integer\", \"\",0\n"
                "\t\tP: \"CoordAxisSign\", \"int\", \"Integer\", \"\",1\n"
                "\t\tP: \"UnitScaleFactor\", \"double\", \"Number\", \"\",1\n\t}\n}\n")
        f.write("Definitions:  {\n\tVersion: 100\n\tCount: 2\n"
                "\tObjectType: \"Geometry\" {\n\t\tCount: 1\n\t}\n"
                "\tObjectType: \"Model\" {\n\t\tCount: 1\n\t}\n}\n")
        f.write("Objects:  {\n")
        f.write("\tGeometry: 1000, \"Geometry::%s\", \"Mesh\" {\n" % nome)
        f.write("\t\tVertices: *%d {\n\t\t\ta: %s\n\t\t}\n"
                % (pos.size, lista(pos.ravel())))
        f.write("\t\tPolygonVertexIndex: *%d {\n\t\t\ta: %s\n\t\t}\n"
                % (plana.size, lista(plana, 12, 0)))
        f.write("\t\tLayerElementNormal: 0 {\n\t\t\tVersion: 101\n"
                "\t\t\tName: \"\"\n\t\t\tMappingInformationType: \"ByVertice\"\n"
                "\t\t\tReferenceInformationType: \"Direct\"\n"
                "\t\t\tNormals: *%d {\n\t\t\t\ta: %s\n\t\t\t}\n\t\t}\n"
                % (nor.size, lista(nor.ravel())))
        vt = uv.copy()
        vt[:, 1] = 1.0 - vt[:, 1]
        f.write("\t\tLayerElementUV: 0 {\n\t\t\tVersion: 101\n"
                "\t\t\tName: \"UVMap\"\n\t\t\tMappingInformationType: \"ByVertice\"\n"
                "\t\t\tReferenceInformationType: \"Direct\"\n"
                "\t\t\tUV: *%d {\n\t\t\t\ta: %s\n\t\t\t}\n\t\t}\n"
                % (vt.size, lista(vt.ravel())))
        f.write("\t\tLayer: 0 {\n\t\t\tVersion: 100\n"
                "\t\t\tLayerElement:  {\n\t\t\t\tType: \"LayerElementNormal\"\n"
                "\t\t\t\tTypedIndex: 0\n\t\t\t}\n"
                "\t\t\tLayerElement:  {\n\t\t\t\tType: \"LayerElementUV\"\n"
                "\t\t\t\tTypedIndex: 0\n\t\t\t}\n\t\t}\n\t}\n")
        f.write("\tModel: 2000, \"Model::%s\", \"Mesh\" {\n\t\tVersion: 232\n"
                "\t\tProperties70:  {\n"
                "\t\t\tP: \"Lcl Scaling\", \"Lcl Scaling\", \"\", \"A\",100,100,100\n"
                "\t\t}\n\t\tShading: T\n\t\tCulling: \"CullingOff\"\n\t}\n")
        f.write("}\n\nConnections:  {\n\tC: \"OO\",2000,0\n\tC: \"OO\",1000,2000\n}\n")
    return caminho


def main():
    entrada, pasta = sys.argv[1], sys.argv[2]
    nome = sys.argv[3] if len(sys.argv) > 3 else "cavaleiro"
    os.makedirs(pasta, exist_ok=True)
    js, blob = abrir(entrada)
    p = js["meshes"][0]["primitives"][0]
    pos = ler(js, blob, p["attributes"]["POSITION"]).astype(np.float64)
    uv = ler(js, blob, p["attributes"]["TEXCOORD_0"]).astype(np.float64)
    nor = ler(js, blob, p["attributes"]["NORMAL"]).astype(np.float64)
    idx = ler(js, blob, p["indices"]).reshape(-1, 3).astype(np.int64)
    print("malha: %d vertices, %d triangulos" % (len(pos), len(idx)))

    texturas = {}
    for img in js.get("images", []):
        v = js["bufferViews"][img["bufferView"]]
        ini = v.get("byteOffset", 0)
        papel = ("basecolor" if "basecolor" in img.get("name", "")
                 else "normal" if "normal" in img.get("name", "") else "rm")
        arquivo = "%s_%s.jpg" % (nome, papel)
        open(os.path.join(pasta, arquivo), "wb").write(blob[ini:ini + v["byteLength"]])
        texturas[papel] = arquivo

    escrever_obj(pasta, nome, pos, uv, nor, idx, texturas)

    caminho_zip = os.path.join(pasta, nome + "_obj.zip")
    with zipfile.ZipFile(caminho_zip, "w", zipfile.ZIP_DEFLATED) as z:
        for arquivo in [nome + ".obj", nome + ".mtl"] + list(texturas.values()):
            z.write(os.path.join(pasta, arquivo), arquivo)

    print("ZIP: %s  (%.1f MB)" % (caminho_zip, os.path.getsize(caminho_zip) / 1e6))


if __name__ == "__main__":
    main()
