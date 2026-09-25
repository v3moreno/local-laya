# local-laya

Local [laya](https://pypi.org/project/laya/) decision daemon + agent tooling for a single-GPU workstation
(RTX 4050 laptop, 6 GB VRAM).

## Components

| File | Purpose |
|---|---|
| `laya-serve` | Daemon launcher: `./laya-serve cpu` → :8123, `./laya-serve gpu` → :8124 (lazy-loads checkpoints, honors `laya.env`) |
| `serve.py` | HTTP server — everything stock `laya.serve` serves, plus `POST /v1/systemone/batch` |
| `laya-mcp.py` | stdio **MCP server proxying to the daemon** — agents get laya tools without loading checkpoints |
| `laya-gate.py` | **hook engine** — doc-read gate, destructive-command gate, injection screen, route advisory. Speaks claude + hermes hook protocols |
| `laya-mcp-install` | Registers MCP server, hooks and plugins with every installed agent. Idempotent; `./laya-mcp-install [agent...]` |
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

| Agent | Mechanism | Enforcement |
|---|---|---|
| claude | MCP + `settings.json` hooks | **hard** — Read/Bash gated, PostToolUse injection screen, prompt route advisory |
| hermes | MCP + `config.yaml` hooks | **hard** — `read_file`/`terminal` gated (`pre_tool_call`), `pre_llm_call` advisory |
| opencode | MCP + `plugins/laya.js` | **hard** — `tool.execute.before` delegates to `laya-gate.py` |
| pi, omp | native extension | **hard** — `tool_call` blocking + injection guard + danger gate |
| codex, crush, grok, copilot | MCP only | soft — tools + server `instructions`; no hook surface for read-gating |

`laya-gate.py` wire protocol: JSON event on stdin (claude's `tool_name`/`tool_input`/`session_id`/`cwd`
shape), decision JSON on stdout. Third arg selects the dialect: `laya-gate.py pretool hermes` emits
`{"decision":"block",...}` instead of `hookSpecificOutput`. Gate scope defaults to `docs/` under cwd
(`LAYA_GATE_DOCS`); state is per-session under `$XDG_STATE_HOME/laya-gate/`. Debug with
`LAYA_GATE_DEBUG=1` → `$XDG_STATE_HOME/gate-debug.log`. Decision calls from
[ask-jev](https://github.com/v3moreno/ask-jev) (`jev_*` MCP tools, `ask-jev` CLI) open the doc gate
the same as laya calls.

Run `./laya-mcp-install` once; for crush/grok the omarchy-local-ai fork writes the block on every `open`.
Set `LAYA_MCP=off` to disable the plugin-side injection.

Requires `mcp` in `.venv`: `uv pip install mcp`.
