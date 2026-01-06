# Claude Code Docker Environment

A lightweight, reproducible Docker setup for running **Claude Code CLI** inside a Node.js 24 Alpine container with full POSIX shell support. While configured for Claude, this environment can be adapted to other AI tools (eg. Gemini CLI).

## Overview

This Docker configuration provides a minimal, isolated Node.js environment specifically designed for **Claude Code CLI**. It ensures the AI agent runs correctly inside a container with proper POSIX shell support, enabling AI-assisted development while keeping your host system clean and secure.

**What it does:**
- Creates a lightweight Alpine Linux container with Node.js 24
- Installs essential development tools: **Git**, **Python 3**, **Docker CLI**, **curl**, and **wget** (openssh-client disabled by default)
- Installs bash for POSIX shell compatibility
- Automatically installs the latest `@anthropic-ai/claude-code` package (configurable)
- Mounts your local project directory for seamless file access
- Provides an interactive shell session for development work

## Prerequisites

Before using this Docker environment, ensure you have:

- **Docker & Docker Compose**: [Install Docker Desktop](https://docs.docker.com/get-docker/) or Docker Engine
- **AI Provider Account**: Access to [Claude Code CLI](https://claude.ai/code) or your preferred provider
- **Git** (optional): For cloning repositories into the workspace

## 🚀 Quick Start

### 1. Clone or Download

```bash
## Clone this repository
## Or download the files directly to your project directory
git clone https://github.com/zainibeats/claude-code-docker
cd claude-code-docker
```

### 2. Configure Project Path

Edit `docker-compose.yml` and replace `Path/To/Directory` with your actual project path:

```yaml
volumes:
  ## Replace with your local project directory
  - Path/To/Directory:/workspace
```

**Examples:**
```yaml
## For Linux/macOS
- /home/user/my-project:/workspace
- /Users/john/documents/coding/my-app:/workspace

## For Windows
- C:\Users\John\Projects\my-app:/workspace
```

### 3. Build and Run

```bash
## Build the Docker image
docker compose build
```
```bash
## Start interactive session
docker compose run claude
```

### 4. Start Claude

Once inside the container:

```bash
## Initialize or use Claude Code
claude
```

## Configuration

### Using Other AI Providers (e.g., Gemini CLI)

This environment is designed to be provider-agnostic. You can easily replace Claude Code with any other CLI tool available on npm (like Gemini CLI).

1. Open `Dockerfile`
2. Locate the installation command:
   ```dockerfile
   RUN npm install -g @anthropic-ai/claude-code
   ```
3. Replace it with your preferred package:
   ```dockerfile
   ## Example: Installing Gemini CLI
   RUN npm install -g @google/gemini-cli
   ```
> Optional: Change other instances of `claude` in Dockerfile to gemini 

4. Rebuild the image: `docker compose build`

### Docker Compose Options

**Option 1: Use Pre-built Image (Recommended)**
```yaml
services:
  claude:
    image: skimming124/claude-code-docker  ## Pull from registry
    ## ... rest of config
```

**Option 2: Build from Source**
```yaml
services:
  claude:
    build: .  ## Build using local Dockerfile
    ## ... rest of config
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SHELL` | Shell environment | `/bin/bash` |
| `NODE_ENV` | Node environment | `development` |

### Volume Mounting

The container mounts your local directory to `/workspace`:

## Usage

### Basic Workflow

```bash
## 1. Build the image (one time)
docker compose build

## 2. Start container
docker compose run claude

## 3. Use the CLI (claude, gemini, etc.)
claude

## 4. Exit with Ctrl+D or 'exit'
```

### Container Management

```bash
## View running containers
docker ps

## Stop container
docker stop claude

## Restart container (preserves state)
docker start -ai claude

## Remove container
docker rm claude

## Remove image
docker rmi skimming124/claude-code-docker
```
