# local-laya

Local [laya](https://pypi.org/project/laya/) decision daemon + agent tooling for a single-GPU workstation
(RTX 4050 laptop, 6 GB VRAM).

## Components

| File | Purpose |
|---|---|
| `laya-serve` | Daemon launcher: `./laya-serve cpu` → :8123, `./laya-serve gpu` → :8124 (lazy-loads checkpoints, honors `laya.env`) |
| `serve.py` | HTTP server — everything stock `laya.serve` serves, plus `POST /v1/systemone/batch` |
| `laya-mcp.py` | stdio **MCP server proxying to the daemon** — agents get laya tools without loading checkpoints |
| `laya-mcp-install` | Registers the MCP server / pi extension with every installed agent. Idempotent; `./laya-mcp-install [agent...]` |
| `systemd/` | `laya-cpu.service`, `laya-gpu.service` user units |

## HTTP API

```
GET  /health                    {"status":"ok","loaded":[...],"device":"cpu|cuda"}
POST /v1/systemone              {"state": "...", "questions": {...}}   → single decision
POST /v1/systemone/batch        {"requests":[{"state":...,"questions":...}, ...]} → {"results":[...]}
                                or {"states": [...], "questions": {...}} shorthand
```

Batch runs the same questions over N states in one forward pass — the reason
`laya_filter`/`laya_triage` score whole doc sets in a single call. Auth: `Authorization: Bearer $LAYA_API_KEY` when set.

## MCP server

`laya-mcp.py` exposes the agent-facing tool surface over stdio:

`laya_status` · `laya_route` · `laya_filter` · `laya_triage` · `laya_yesno` · `laya_pick` · `laya_decide`

Daemon selection: `LAYA_URL`, else probes `:8124` (gpu) then `:8123` (cpu) — same policy as `ask`.
Unlike `laya[mcp]`'s bundled server, this proxies to the warm daemon instead of embedding a Router per client.

## Agent support (omarchy local-ai)

| Agent | Mechanism | Config |
|---|---|---|
| claude | MCP | `claude mcp add --scope user` |
| codex | MCP | `~/.codex/config.toml` `[mcp_servers.laya]` |
| opencode | MCP | `~/.config/opencode/opencode.json` `mcp.laya` |
| crush | MCP | plugin injects `mcp.laya` into generated `crush.json` |
| grok | MCP | `[mcp_servers.laya]` in GROK_HOME `config.toml` (plugin-generated) |
| copilot | MCP | `~/.copilot/mcp-config.json` |
| hermes | MCP | `hermes mcp add` → `~/.hermes/config.yaml` |
| pi, omp | native extension | `extensions/laya.js` in the agent dir (no MCP — gets *blocking* hooks MCP can't provide) |

Run `./laya-mcp-install` once; for crush/grok the omarchy-local-ai fork writes the block on every `open`.
Set `LAYA_MCP=off` to disable the plugin-side injection.

Requires `mcp` in `.venv`: `uv pip install mcp`.
