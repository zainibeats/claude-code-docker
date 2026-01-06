# Claude Code Docker Environment

A lightweight, reproducible Docker setup for running **Claude Code CLI** inside a Node.js 24 Alpine container with full POSIX shell support.

## Overview

This Docker configuration provides a minimal, isolated Node.js environment specifically designed for **Claude Code CLI**. It ensures Claude runs correctly inside a container with proper POSIX shell support, enabling AI-assisted development while keeping your host system clean and secure.

**What it does:**
- Creates a lightweight Alpine Linux container with Node.js 24
- Installs bash for POSIX shell compatibility (required by Claude CLI)
- Automatically installs the latest `@anthropic-ai/claude-code` package
- Mounts your local project directory for seamless file access
- Provides an interactive shell session for development work

## Features

- **Lightweight**: Based on `node:24-alpine` for minimal resource usage
- **POSIX Compliant**: Bash shell preinstalled for Claude CLI compatibility
- **Persistent Storage**: Local project directory mounted as `/workspace`
- **Auto-Installation**: Claude Code CLI installed globally during build
- **Interactive**: Full TTY support for seamless CLI interaction
- **Isolated**: Development environment separate from host system
- **Reproducible**: Consistent setup across different machines

## Prerequisites

Before using this Docker environment, ensure you have:

- **Docker**: [Install Docker Desktop](https://docs.docker.com/get-docker/) or Docker Engine
- **Docker Compose**: Usually included with Docker Desktop
- **Claude Account**: Access to [Claude Code CLI](https://claude.ai/code)
- **Git** (optional): For cloning repositories into the workspace

## 🚀 Quick Start

### 1. Clone or Download

```bash
## Clone this repository
git clone https://github.com/zainibeats/claude-code-docker
cd claude-code-docker

## Or download the files directly to your project directory
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

## Start interactive session
docker compose run claude
```

### 4. Start Claude

Once inside the container:

```bash
## Initialize Claude Code (first time only)
claude

## Subsequent uses
claude
```

## Configuration

### Docker Compose Options

The `docker-compose.yml` file supports two modes:

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

- **Host**: Your local project directory
- **Container**: `/workspace` (working directory)
- **Access**: Read/write from both sides
- **Persistence**: Files persist after container stops

## Usage

### Basic Workflow

```bash
## 1. Build the image (one time)
docker compose build

## 2. Start container
docker compose run claude

## 3. Use Claude Code
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

##S Remove image
docker rmi skimming124/claude-code-docker
```
