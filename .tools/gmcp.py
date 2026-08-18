#!/usr/bin/env python3
"""Ponte Claude <-> Godot: fala JSON-RPC direto com o addon godot_mcp (127.0.0.1:6400).

O addon responde de forma sincrona no POST /message, entao nao usamos SSE
(a conexao SSE guardava respostas pendentes e embaralhava o estado).

Uso:
  gmcp.py tools                       lista as tools do editor
  gmcp.py call <tool> '<json args>'   chama uma tool
  gmcp.py gd <arquivo.gd>             roda GDScript (corpo de funcao) no editor
"""
import json, sys, urllib.request

URL = "http://127.0.0.1:6400/message"
_id = [0]


def rpc(method, params=None):
    _id[0] += 1
    body = json.dumps({"jsonrpc": "2.0", "id": _id[0], "method": method,
                       "params": params or {}}).encode()
    req = urllib.request.Request(URL, data=body,
                                 headers={"Content-Type": "application/json"})
    try:
        raw = urllib.request.urlopen(req, timeout=120).read()
    except Exception as e:
        sys.exit("Sem resposta do Godot (%s). O editor esta aberto e o painel "
                 "MCP ligado?" % e)
    if not raw.strip():
        sys.exit("Godot aceitou mas nao respondeu (202) — veja o log do editor.")
    return json.loads(raw)


def handshake():
    rpc("initialize", {"protocolVersion": "2024-11-05", "capabilities": {},
                       "clientInfo": {"name": "gmcp", "version": "1"}})


def show(res):
    if "error" in res:
        sys.exit("ERRO: " + json.dumps(res["error"], ensure_ascii=False, indent=2))
    out = res.get("result", {})
    if isinstance(out, dict):
        for item in out.get("content", []):
            if item.get("type") == "text":
                print(item["text"])
                return
    print(json.dumps(out, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "tools"
    handshake()
    if cmd == "tools":
        for t in rpc("tools/list")["result"]["tools"]:
            print(f'{t["name"]}: {t["description"][:90]}')
    elif cmd == "call":
        args = json.loads(sys.argv[3]) if len(sys.argv) > 3 else {}
        show(rpc("tools/call", {"name": sys.argv[2], "arguments": args}))
    elif cmd == "gd":
        show(rpc("tools/call", {"name": "execute_gdscript",
                                "arguments": {"code": open(sys.argv[2]).read()}}))
    else:
        sys.exit(__doc__)
