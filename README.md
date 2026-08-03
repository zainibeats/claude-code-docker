# contagent

A provider-agnostic Docker environment for running AI coding agents (Claude Code, Codex, Gemini CLI, etc.) that aims to be indistinguishable from running them directly on your host.

## Overview

**What it does:**
- Debian-based Node.js 24 container with glibc, so prebuilt Python wheels, native npm modules, and vendor binaries behave exactly as they do on the host
- Ships the tools coding agents actually reach for: Git, GitHub CLI, Python 3 + uv, pytest, ruff, Docker CLI + Buildx + Compose, ripgrep, jq, curl, SSH client, GNU coreutils, editors, tmux
- Persists agent credentials, settings, project history, and shell history across sessions in a named volume — you log in once, not every run
- Matches the container user's UID/GID to your host user so bind-mounted files keep correct ownership
- Mounts your workspace at its **host path**, so paths mean the same thing inside and out
- Forwards your SSH agent and provider API keys, so `git push` and agent auth work without extra setup
- Gives the agent passwordless `sudo` inside the container, so a missing package is a one-line fix rather than a dead end
- Forwards `TERM`, `COLORTERM`, and `TZ` so colours and timestamps match your host terminal
- Mounts the host Docker socket so agents can run Docker commands without a nested daemon

**Why containerise at all:** the container is the security boundary. Running the agent as a non-root user in a disposable container is what makes full-autonomy modes — `claude --dangerously-skip-permissions`, `codex --full-auto` — a reasonable thing to do. Blast radius is the mounted workspace, not your home directory.

## Prerequisites

- **Docker & Docker Compose**: [Install Docker Desktop](https://docs.docker.com/get-docker/) or Docker Engine
- **AI Provider Account**: Access to your preferred CLI tool (Claude Code, Codex, etc.)

## Quick Start

### 1. Clone

```bash
git clone https://github.com/zainibeats/contagent
cd contagent
```

### 2. Configure

```bash
cp .env.example .env
```

Edit `.env` — at minimum set the workspace path and your host user IDs:

```bash
PATH_TO_WORKSPACE=/home/user/my-project
HOST_UID=1000   # id -u
HOST_GID=1000   # id -g
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=you@example.com
```

> Getting `HOST_UID`/`HOST_GID` right matters. Compose cannot read them automatically: `$UID` is a shell variable that is never exported, and `$GID` does not exist in bash at all. If they are wrong, the entrypoint prints a warning at startup telling you what to set.

### 3. Build and Run

```bash
## Build the image (one time, and after changing AGENT_PACKAGES)
docker compose build

## Start an interactive session
docker compose run --rm contagent
```

### 4. Use your agent

```bash
claude          # or: codex, gemini
```

Authenticate once. Credentials live in the `agent-home` volume, so subsequent sessions start logged in.

## Configuration

### Switching AI Providers

Set `AGENT_PACKAGES` in `.env` and rebuild — no need to edit the Dockerfile:

```bash
AGENT_PACKAGES=@openai/codex
```

```bash
docker compose build
```

Space-separated values install several at once:

```bash
AGENT_PACKAGES="@anthropic-ai/claude-code @google/gemini-cli"
```

### Updating an Installed Agent

The global npm prefix (`/opt/npm-global`) is owned by the agent user, so self-updates work from inside the container without `sudo`:

```bash
npm install -g @anthropic-ai/claude-code@latest
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PATH_TO_WORKSPACE` | Host path mounted at the same path inside the container | *(required)* |
| `HOST_UID` / `HOST_GID` | Host user IDs to match; run `id -u` / `id -g` | `1000` |
| `AGENT_USER` | Container username | `agent` |
| `AGENT_SUDO` | Passwordless sudo for the agent user (`0` disables) | `1` |
| `AGENT_PACKAGES` | npm packages installed globally at build time | `@anthropic-ai/claude-code` |
| `GIT_USER_NAME` / `GIT_USER_EMAIL` | Git identity written at container startup | *(empty)* |
| `TZ` | Container timezone | `UTC` |
| `TERM` / `COLORTERM` | Forwarded from the host terminal | `xterm-256color` / *(empty)* |
| `ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, … | Provider credentials, forwarded if set | *(empty)* |
| `GH_TOKEN` | Token for `gh`; also configures git credentials for HTTPS pushes | *(empty)* |
| `SSH_AUTH_SOCK` | Host SSH agent socket to forward | host value |

### Persistence

`/home/agent` is a named Docker volume (`agent-home`). It holds agent credentials and settings (`~/.claude`, `~/.codex`, …), shell history, and caches. To start completely fresh:

```bash
docker compose down -v
```

Global tooling lives *outside* the home volume (`/opt/venv`, `/opt/npm-global`), so rebuilding the image still updates it even when the volume is warm.

### Workspace Paths

The workspace is bind-mounted at its host path rather than at a fixed `/workspace`. This is what makes Docker socket access behave correctly: when the agent runs `docker run -v $(pwd):/app`, the host daemon resolves that path against the host filesystem, and it now points at the same directory. `/workspace` still exists as a symlink to the workspace for convenience.

Avoid workspace paths containing spaces — Compose's short volume syntax cannot express them.

### Git Authentication

Two paths, both wired up by default:

- **SSH** — your host SSH agent is forwarded to `/ssh-agent`, so `git push` uses your existing keys without copying private keys into the container. If no agent is running, the entrypoint detects the dead socket and unsets `SSH_AUTH_SOCK`. On macOS, set `SSH_AUTH_SOCK=/run/host-services/ssh-auth.sock` in `.env`.
- **HTTPS** — set `GH_TOKEN` and the entrypoint runs `gh auth setup-git`, so pushes and `gh` both authenticate.

### Docker Access

The Compose file mounts `/var/run/docker.sock` and sets `DOCKER_HOST`. This lets the agent run `docker` and `docker compose` against the host daemon.

This is usually a better default than Docker-in-Docker for an interactive coding-agent container: it avoids a privileged nested daemon, keeps image builds cached by the host, and works with the same containers/images you already use locally. **Treat Docker socket access as privileged access to the host** — anything with the socket can start a privileged container and escape.

### Codex Sandbox Support

Codex may use Bubblewrap to sandbox shell commands. Creating namespaces inside a container needs elevated privileges, and without them commands fail before they start:

```text
bwrap: No permissions to creating new namespace
```

Because `SYS_ADMIN` plus unconfined seccomp/AppArmor meaningfully weakens the container boundary, it is **not** in the default profile. Opt in with the overlay:

```bash
docker compose -f docker-compose.yml -f docker-compose.codex.yml run --rm contagent
```

On some Linux hosts the kernel must also allow unprivileged user namespaces:

```bash
sudo sysctl kernel.unprivileged_userns_clone=1
```

To make that persistent on Debian/Ubuntu hosts, add `kernel.unprivileged_userns_clone=1` under `/etc/sysctl.d/` and reload sysctl settings.

Often the better option inside an already-isolated container is to disable the agent's *own* sandbox and let the container be the boundary, leaving the default profile intact.

### Python

A shared virtualenv at `/opt/venv` is first on `PATH` and owned by the agent user, so `pip install` works normally instead of failing with `externally-managed-environment`. `uv` and `uvx` are installed for faster installs and one-off tool runs. `pytest`, `pytest-cov`, and `ruff` are preinstalled.

### Git Safe Directory

The entrypoint runs:

```bash
git config --global --replace-all safe.directory '*'
```

This avoids Git's `detected dubious ownership` error for bind-mounted repositories. The container operates on a workspace you explicitly mounted for the agent, so all repositories are marked safe inside it.

### Project Structure

```
contagent/
├── Dockerfile                # Container image definition
├── docker-compose.yml        # Service configuration
├── docker-compose.codex.yml  # Opt-in overlay for nested sandboxes
├── entrypoint.sh             # UID/GID matching, credentials, user switching
├── bashrc                    # Interactive shell defaults
├── .dockerignore
├── .env.example
└── README.md
```

## Usage

### Basic Workflow

```bash
## 1. Build (one time)
docker compose build

## 2. Start a throwaway session
docker compose run --rm contagent

## 3. Run your agent
claude

## 4. Exit
exit
```

### Long-Running Container

To keep one container around and attach to it from several terminals:

```bash
docker compose up -d
docker compose exec contagent bash
docker compose down
```

### Container Management

```bash
## Rebuild after changing the Dockerfile or AGENT_PACKAGES
docker compose build

## Remove the image
docker compose down --rmi local

## Remove the image and wipe persisted agent state
docker compose down --rmi local -v
```
