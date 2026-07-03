# contagent

A lightweight, provider-agnostic Docker environment for running AI coding agents (Claude Code, Codex, Gemini CLI, etc.) inside a Node.js 24 Alpine container.

## Overview

**What it does:**
- Creates a minimal Alpine Linux container with Node.js 24
- Installs practical coding-agent tools: Git, Python 3, pytest, Docker CLI + Compose, curl, ripgrep, jq, SSH client, editors, and common Unix utilities
- Automatically matches the container user's UID/GID to your host user so bind-mounted files have correct ownership
- Creates a container-local Git identity from `.env` when `GIT_USER_NAME` and `GIT_USER_EMAIL` are set
- Mounts your local project directory for seamless file access
- Marks Git repositories as safe inside the container so bind-mounted workspaces do not trigger dubious ownership errors
- Mounts the host Docker socket so agents can run Docker commands without running a nested Docker daemon
- Enables Bubblewrap-based command sandboxes used by tools such as Codex
- Provides an interactive shell session

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

Copy `.env.example` to `.env` and set your workspace path:

```bash
cp .env.example .env
```

Edit `.env`:
```
PATH_TO_WORKSPACE=/home/user/my-project
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=you@example.com
```

### 3. Build and Run

```bash
## Build the Docker image
docker compose build

## Start an interactive session
docker compose run contagent
```

### 4. Use your agent

```bash
## Default: Claude Code
claude

## Or whichever CLI you installed
codex
gemini
```

## Configuration

### Switching AI Providers

Edit `Dockerfile` to install your preferred tool, then rebuild:

```dockerfile
## Install your preferred AI CLI tool (rebuild after changing):
RUN npm install -g @anthropic-ai/claude-code
## RUN npm install -g @openai/codex
## RUN npm install -g @google/gemini-cli
```

```bash
docker compose build
```

### Updating an Installed Agent

Update a globally installed agent in the running container from the host:

```bash
docker compose exec --user root contagent npm install -g @openai/codex@latest
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PATH_TO_WORKSPACE` | Host path to mount as `/workspace` | *(required)* |
| `HOST_UID` | UID for the container user | `1000` |
| `HOST_GID` | GID for the container user | `1000` |
| `AGENT_USER` | Container username | `agent` |
| `GIT_USER_NAME` | Git `user.name` written to `/home/$AGENT_USER/.gitconfig` at container startup | *(empty)* |
| `GIT_USER_EMAIL` | Git `user.email` written to `/home/$AGENT_USER/.gitconfig` at container startup | *(empty)* |

To override UID/GID or username at runtime:

```bash
UID=1001 GID=1001 AGENT_USER=myuser docker compose run contagent
```

### Docker Access

The Compose file mounts `/var/run/docker.sock` and sets `DOCKER_HOST=unix:///var/run/docker.sock`. This lets the agent run `docker` and `docker compose` commands against the host Docker daemon.

This is usually a better default than Docker-in-Docker for an interactive coding-agent container: it avoids a privileged nested daemon, keeps image builds cached by the host, and works with the same containers/images you already use locally. Treat Docker socket access as privileged access to the host.

### Codex Sandbox Support

Codex may use Bubblewrap to sandbox shell commands. Without namespace support inside the container, commands can fail before they start with an error like:

```text
bwrap: No permissions to creating new namespace
```

The image installs `bubblewrap`, and the Compose service adds `SYS_ADMIN` plus relaxed seccomp/AppArmor settings so nested command sandboxes can start.

On some Linux hosts, the host kernel must also allow unprivileged user namespaces:

```bash
sudo sysctl kernel.unprivileged_userns_clone=1
```

To make that persistent on Debian/Ubuntu hosts, add `kernel.unprivileged_userns_clone=1` under `/etc/sysctl.d/` and reload sysctl settings.

### Git Safe Directory

The entrypoint runs:

```bash
git config --global --replace-all safe.directory '*'
```

This avoids Git's `detected dubious ownership` error for bind-mounted repositories. The container is intended to operate on a workspace you explicitly mounted for the agent, so all repositories are marked safe inside the container.

### Git Identity

Set your Git commit identity in `.env`:

```env
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=you@example.com
```

At container startup, the entrypoint writes these values to the agent user's global Git config:

```bash
git config --global --replace-all user.name "$GIT_USER_NAME"
git config --global --replace-all user.email "$GIT_USER_EMAIL"
```

This creates `/home/$AGENT_USER/.gitconfig` inside the container without mounting your host `.gitconfig`.

### Project Structure

```
contagent/
├── Dockerfile          # Container image definition
├── docker-compose.yml  # Service configuration
├── entrypoint.sh       # Runtime UID/GID matching & user switching
├── .env.example        # Environment variable template
└── README.md
```

## Usage

### Basic Workflow

```bash
## 1. Build (one time)
docker compose build

## 2. Start container
docker compose run contagent

## 3. Run your agent
claude

## 4. Exit
exit
```

### Container Management

```bash
## View running containers
docker ps

## Stop container
docker stop contagent

## Remove container
docker rm contagent

## Remove image
docker compose down --rmi local
```
