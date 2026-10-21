# opencode on Render

Run opencode as a hosted AI coding agent with the browser UI and `opencode attach`.

[![Deploy to Render](https://render.com/images/deploy-to-render-button.svg)](https://render.com/deploy-template/api/github/start?template_repo=opencode-on-render)

## What you get

- A single Render Web Service running `opencode web`
- The built-in opencode web UI on your Render URL
- Remote TUI access with `opencode attach`
- A `standard` instance to avoid OOM loops on startup and active agent sessions
- A 1 GB persistent disk for opencode state and your working tree
- Optional repo cloning into `/root/project-data/workspace` on first boot
- The Render OpenCode plugin installed by default
- Hashcat with a CPU OpenCL backend

## Hashcat

The Docker image installs Debian Bookworm's `hashcat` package and
`pocl-opencl-icd` for CPU-based OpenCL execution. This uses Debian's packaged
version, which may differ from the latest upstream release.

Save, commit, and push the Dockerfile change, then rebuild and redeploy the
Render service. Restarting OpenCode in an existing container will not install
these packages.

In a shell inside the rebuilt server, or through OpenCode's shell tool, run:

```sh
hashcat --version
hashcat -I
```

The first command prints the installed version. The second lists available
compute backends and devices; confirm that a CPU device is detected before use.
GPU acceleration is not configured. CPU compatibility and available memory
depend on the host, and CPU-heavy work can compete with the OpenCode server.

Package documentation: [Hashcat](https://packages.debian.org/bookworm/hashcat)
and [PoCL OpenCL backend](https://packages.debian.org/bookworm/pocl-opencl-icd).

## How to use it

### From your browser

Deploy the template, then open the Render service URL.

Log in with:

- Username: `opencode`
- Password: the generated `OPENCODE_SERVER_PASSWORD` value in the Render Dashboard

### From your terminal

Install or update the local terminal UI to match the hosted OpenCode version:

```bash
npm install -g opencode-ai@1.19.3
opencode --version
```

The version command should print `1.19.3`.

Attach to the **Render OpenCode service URL**, not a separate static-site or
dashboard URL. Replace the example URL below with your service's URL.

`opencode attach` does not prompt for a server password. Render's environment
variables are not automatically available on your local device. In Bash, use
this hidden-input prompt and paste the generated `OPENCODE_SERVER_PASSWORD`
from your Render service's Environment page:

```bash
(
  read -rsp "OpenCode server password: " OPENCODE_SERVER_PASSWORD || exit 1
  printf '\n'
  export OPENCODE_SERVER_PASSWORD
  opencode attach https://your-service.onrender.com --username opencode
)
```

The subshell keeps the password out of shell history and discards its local
copy when the client exits. If you changed `OPENCODE_SERVER_USERNAME` in Render,
replace `opencode` after `--username` with the configured username. Never paste
your password or provider keys into an issue or chat.

## Updating OpenCode and the terminal UI

The Docker image pins `opencode-ai` to **1.19.3**, the current stable npm release
when this template was updated. OpenCode and its terminal UI (TUI) are supplied
by the same package; there is no separate TUI dependency to upgrade. Keep the
local terminal client on the same version as the hosted server.

To apply this update:

1. Save, commit, and push the Dockerfile change to the repository used by Render.
2. In the Render service, choose **Manual Deploy → Clear build cache & deploy**.
   Restarting an existing container does not update its installed OpenCode.
3. Run the versioned npm install command in **From your terminal** on your local
   machine, then reconnect with `opencode attach`.

The Docker build prints `opencode --version` so you can verify the installed
server version in the build log. Future updates should change `OPENCODE_VERSION`
in `Dockerfile` and the matching client version in this README together.

Sources: [OpenCode 1.19.3 release notes](https://github.com/anomalyco/opencode/releases/tag/v1.19.3),
[npm package](https://www.npmjs.com/package/opencode-ai), and
[CLI documentation](https://opencode.ai/docs/cli/).

## Bring your own repo

Set `REPO_URL` during deploy to clone a working tree into `/root/project-data/workspace` on first boot.

For a public repo:

```txt
REPO_URL=https://github.com/your-org/your-repo.git
```

For a specific branch:

```txt
REPO_URL=https://github.com/your-org/your-repo.git
REPO_BRANCH=main
```

For a private GitHub repo, also set `GITHUB_TOKEN` to a token that can read the repo.

The startup script only clones when `/root/project-data/workspace` is empty. If `/root/project-data/workspace` already has files, it leaves them alone.

If you do not set `REPO_URL`, the service creates a small default Git project in `/root/project-data/workspace` so the web UI has a project to open.

## Server command

The template defaults to:

```txt
OPENCODE_SERVER_COMMAND=web
```

That starts opencode's web UI and API on the same Render URL.

Both `web` and `serve` support authenticated `opencode attach`. Use
`OPENCODE_SERVER_COMMAND=serve` only when you want a headless backend instead
of the web UI; changing modes is not a general fix for attachment errors.

## Terminal troubleshooting

You can check the backend without a working terminal:

1. Open `https://your-service.onrender.com/global/health` in a browser, using
   your actual **Render OpenCode service URL**. Sign in with the configured
   username and generated server password if the browser requests them.
2. A healthy backend returns JSON such as
   `{"healthy":true,"version":"1.19.3"}`. Check the returned version rather than
   assuming the Dockerfile update has reached the running service.
3. If you see `401` or a repeated sign-in prompt, verify the server credentials.
   If you get HTML or a different dashboard instead of health JSON, check the
   destination URL and routing before changing OpenCode's server command.
4. If the service does not load or returns `502`/`503`, inspect Render's current
   live deployment and runtime logs. Check for a failed startup or deployment;
   the latest attempted deployment is not necessarily the live one.

If health succeeds but the browser terminal is blank or disconnected, capture
its failed PTY/WebSocket request status (from the browser's Network panel) and
any matching Render runtime error. API health alone does not verify the terminal
connection. Render supports WebSockets; do not disable server authentication to
work around a terminal failure.

For local OpenCode startup or attach failures, share the exact error text and
local `opencode --version` output, with credentials removed. If no terminal is
available, share the browser health result and the first relevant Render runtime
error instead. Do not delete persistent state or downgrade blindly.

References: [OpenCode server health and authentication](https://opencode.ai/docs/server/),
[OpenCode 1.19.3 attach implementation](https://github.com/anomalyco/opencode/blob/v1.19.3/packages/opencode/src/cli/cmd/attach.ts),
and [WebSockets on Render](https://render.com/docs/websocket).

## Configured providers

Set one or more provider keys in Render:

- `ANTHROPIC_API_KEY` unlocks Anthropic models.
- `OPENROUTER_API_KEY` unlocks OpenRouter models.
- `RENDER_API_KEY` unlocks Render MCP tools.

The service writes these keys into `/root/project-data/opencode/auth.json` using opencode's API-key auth format.

Anthropic OAuth is not supported in this hosted setup. Use `ANTHROPIC_API_KEY`.

## Security notes

This template gives you a remote coding agent, not a hardened sandbox.

The agent can read and write files in its workspace, run shell commands, and use the environment variables you provide. Treat it like a single-tenant development box that can act with your credentials.

Be careful with `RENDER_API_KEY`. Render API keys are broad credentials today. If you set one, opencode can use Render MCP tools with whatever access that key has. Leave `RENDER_API_KEY` unset unless you want the agent to manage Render resources from this service. Remove it when you do not need Render MCP, and rotate it if you expose logs, transcripts, or the service password.

Do not use this template with untrusted users, untrusted prompts, or repos you do not want an AI agent to execute code from.

## Instance size

The template uses Render's `standard` plan by default.

opencode can exceed the memory available on `starter`, especially with the web UI, provider metadata, plugins, MCP tools, and active coding sessions.

## What's pre-wired

The image installs the Render OpenCode plugin from GitHub. It adds:

- `render_validate_blueprint`
- automatic validation when an agent edits `render.yaml` or `render.yml`
- `/deploy-to-render`
- `/check-render-status`
- the `@render` subagent
- bundled Render skills

The startup script also merges the Render MCP server into `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "render": {
      "type": "remote",
      "url": "https://mcp.render.com/mcp",
      "enabled": true,
      "oauth": false,
      "headers": {
        "Authorization": "Bearer {env:RENDER_API_KEY}"
      }
    }
  }
}
```

Set `RENDER_API_KEY` in Render before asking opencode to manage Render resources.

## Disk size

The template starts with a 1 GB persistent disk mounted at:

```txt
/root/project-data
```

The startup script uses that disk for:

- `/root/project-data/opencode` for opencode auth, sessions, and SQLite state
- `/root/project-data/workspace` for the repo or project files the agent edits

To resize it, edit `render.yaml`:

```yaml
disk:
  name: opencode-data
  mountPath: /root/project-data
  sizeGB: 5
```

Then deploy the updated Blueprint.

## Known limitations

- Anthropic OAuth login does not work for hosted opencode. Use `ANTHROPIC_API_KEY`.
- The opencode web UI fetches assets from opencode's CDN at runtime.
- This is single-tenant. Do not share one deployment with multiple users.
- `/root/project-data/workspace` persists across restarts and deploys, but you should still commit and push important work back to your repo.
- The image preinstalls TypeScript language server only. Other language servers can be installed in your repo or a fork of this template.

## Learn more

- [opencode docs](https://opencode.ai/docs)
- [opencode CLI docs](https://opencode.ai/docs/cli/)
- [opencode MCP docs](https://opencode.ai/docs/mcp-servers/)
- [Render OpenCode plugin](https://github.com/render-oss/render-opencode-plugin)
