#!/usr/bin/env python3
"""
Servidor MCP do GitHub em Python (sem necessidade de Docker ou Node.js).
Comunica-se via MCP Stdio (JSON-RPC 2.0) e utiliza a API REST do GitHub e/ou Git local.
"""
import sys
import os
import json
import urllib.request
import urllib.parse
import urllib.error
import subprocess

GITHUB_API_URL = "https://api.github.com"
TOKEN = os.environ.get("GITHUB_PERSONAL_ACCESS_TOKEN") or os.environ.get("GITHUB_TOKEN", "")

def github_request(endpoint, method="GET", data=None):
    url = f"{GITHUB_API_URL}/{endpoint.lstrip('/')}"
    headers = {
        "Accept": "application/vnd.github.v3+json",
        "User-Agent": "Godot-GitHub-MCP/1.0"
    }
    if TOKEN:
        headers["Authorization"] = f"token {TOKEN}"
    
    req_data = json.dumps(data).encode("utf-8") if data is not None else None
    req = urllib.request.Request(url, data=req_data, headers=headers, method=method)
    
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            content = resp.read().decode("utf-8")
            return json.loads(content) if content else {}
    except urllib.error.HTTPError as e:
        err_body = e.read().decode("utf-8")
        try:
            err_json = json.loads(err_body)
            return {"error": f"HTTP {e.code}: {err_json.get('message', err_body)}"}
        except Exception:
            return {"error": f"HTTP {e.code}: {err_body}"}
    except Exception as e:
        return {"error": str(e)}

TOOLS = [
    {
        "name": "github_get_file_contents",
        "description": "Get contents of a file from a GitHub repository.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "owner": {"type": "string", "description": "Repository owner (user or org)"},
                "repo": {"type": "string", "description": "Repository name"},
                "path": {"type": "string", "description": "Path to the file in the repo"},
                "ref": {"type": "string", "description": "Branch, tag, or commit SHA (optional)"}
            },
            "required": ["owner", "repo", "path"]
        }
    },
    {
        "name": "github_list_commits",
        "description": "List commits for a repository.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "owner": {"type": "string", "description": "Repository owner"},
                "repo": {"type": "string", "description": "Repository name"},
                "per_page": {"type": "integer", "description": "Number of commits (default: 10)"},
                "sha": {"type": "string", "description": "Branch or commit SHA (optional)"}
            },
            "required": ["owner", "repo"]
        }
    },
    {
        "name": "github_create_issue",
        "description": "Create a new issue in a GitHub repository.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "owner": {"type": "string", "description": "Repository owner"},
                "repo": {"type": "string", "description": "Repository name"},
                "title": {"type": "string", "description": "Issue title"},
                "body": {"type": "string", "description": "Issue body markdown"},
                "labels": {"type": "array", "items": {"type": "string"}, "description": "Labels"}
            },
            "required": ["owner", "repo", "title"]
        }
    },
    {
        "name": "github_list_issues",
        "description": "List issues for a GitHub repository.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "owner": {"type": "string", "description": "Repository owner"},
                "repo": {"type": "string", "description": "Repository name"},
                "state": {"type": "string", "enum": ["open", "closed", "all"], "description": "Issue state"}
            },
            "required": ["owner", "repo"]
        }
    },
    {
        "name": "github_create_pull_request",
        "description": "Create a new pull request in a GitHub repository.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "owner": {"type": "string", "description": "Repository owner"},
                "repo": {"type": "string", "description": "Repository name"},
                "title": {"type": "string", "description": "PR title"},
                "head": {"type": "string", "description": "Head branch"},
                "base": {"type": "string", "description": "Base branch (e.g. main)"},
                "body": {"type": "string", "description": "PR description"}
            },
            "required": ["owner", "repo", "title", "head", "base"]
        }
    },
    {
        "name": "github_list_pull_requests",
        "description": "List pull requests for a repository.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "owner": {"type": "string", "description": "Repository owner"},
                "repo": {"type": "string", "description": "Repository name"},
                "state": {"type": "string", "enum": ["open", "closed", "all"], "description": "PR state"}
            },
            "required": ["owner", "repo"]
        }
    },
    {
        "name": "github_search_repositories",
        "description": "Search for repositories on GitHub.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "query": {"type": "string", "description": "Search query"},
                "per_page": {"type": "integer", "description": "Results per page (default: 10)"}
            },
            "required": ["query"]
        }
    },
    {
        "name": "github_git_status",
        "description": "Check local git status and current branch information.",
        "inputSchema": {
            "type": "object",
            "properties": {
                "cwd": {"type": "string", "description": "Working directory (optional)"}
            }
        }
    }
]

def handle_tool_call(name, args):
    if name == "github_get_file_contents":
        owner = args.get("owner")
        repo = args.get("repo")
        path = args.get("path")
        ref = args.get("ref")
        endpoint = f"repos/{owner}/{repo}/contents/{path}"
        if ref:
            endpoint += f"?ref={ref}"
        res = github_request(endpoint)
        if "content" in res and res.get("encoding") == "base64":
            import base64
            decoded = base64.b64decode(res["content"]).decode("utf-8", errors="replace")
            return {"content": decoded, "sha": res.get("sha"), "size": res.get("size")}
        return res
        
    elif name == "github_list_commits":
        owner = args.get("owner")
        repo = args.get("repo")
        per_page = args.get("per_page", 10)
        sha = args.get("sha")
        endpoint = f"repos/{owner}/{repo}/commits?per_page={per_page}"
        if sha:
            endpoint += f"&sha={sha}"
        return github_request(endpoint)
        
    elif name == "github_create_issue":
        owner = args.get("owner")
        repo = args.get("repo")
        data = {
            "title": args.get("title"),
            "body": args.get("body", "")
        }
        if "labels" in args:
            data["labels"] = args["labels"]
        return github_request(f"repos/{owner}/{repo}/issues", method="POST", data=data)
        
    elif name == "github_list_issues":
        owner = args.get("owner")
        repo = args.get("repo")
        state = args.get("state", "open")
        return github_request(f"repos/{owner}/{repo}/issues?state={state}")
        
    elif name == "github_create_pull_request":
        owner = args.get("owner")
        repo = args.get("repo")
        data = {
            "title": args.get("title"),
            "head": args.get("head"),
            "base": args.get("base"),
            "body": args.get("body", "")
        }
        return github_request(f"repos/{owner}/{repo}/pulls", method="POST", data=data)
        
    elif name == "github_list_pull_requests":
        owner = args.get("owner")
        repo = args.get("repo")
        state = args.get("state", "open")
        return github_request(f"repos/{owner}/{repo}/pulls?state={state}")
        
    elif name == "github_search_repositories":
        query = urllib.parse.quote(args.get("query", ""))
        per_page = args.get("per_page", 10)
        return github_request(f"search/repositories?q={query}&per_page={per_page}")
        
    elif name == "github_git_status":
        cwd = args.get("cwd") or os.getcwd()
        try:
            out = subprocess.check_output(["git", "status", "-s", "-b"], cwd=cwd, stderr=subprocess.STDOUT).decode()
            return {"status": out}
        except Exception as e:
            return {"error": str(e)}
            
    return {"error": f"Unknown tool: {name}"}

def process_message(msg):
    method = msg.get("method")
    msg_id = msg.get("id")
    
    if method == "initialize":
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "protocolVersion": "2024-11-05",
                "capabilities": {
                    "tools": {}
                },
                "serverInfo": {
                    "name": "github-mcp-python",
                    "version": "1.0.0"
                }
            }
        }
    elif method == "notifications/initialized":
        return None
    elif method == "tools/list":
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "tools": TOOLS
            }
        }
    elif method == "tools/call":
        params = msg.get("params", {})
        tool_name = params.get("name")
        tool_args = params.get("arguments", {})
        result = handle_tool_call(tool_name, tool_args)
        return {
            "jsonrpc": "2.0",
            "id": msg_id,
            "result": {
                "content": [
                    {
                        "type": "text",
                        "text": json.dumps(result, ensure_ascii=False, indent=2)
                    }
                ]
            }
        }
    elif method == "ping":
        return {"jsonrpc": "2.0", "id": msg_id, "result": {}}
    else:
        if msg_id is not None:
            return {
                "jsonrpc": "2.0",
                "id": msg_id,
                "error": {
                    "code": -32601,
                    "message": f"Method not found: {method}"
                }
            }
    return None

def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            msg = json.loads(line)
            resp = process_message(msg)
            if resp:
                sys.stdout.write(json.dumps(resp) + "\n")
                sys.stdout.flush()
        except Exception as e:
            sys.stderr.write(f"Error processing message: {e}\n")
            sys.stderr.flush()

if __name__ == "__main__":
    main()
