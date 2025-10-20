# 🧠 Claude Code Docker Environment

A lightweight, reproducible Docker setup for running **Claude Code CLI** inside a Node.js 24 Alpine container with full POSIX shell support.

## 🚀 Overview

This configuration builds a minimal Node.js environment with `bash` installed so the **Claude CLI** runs correctly inside a Docker container.  
It lets you interact with Claude for code generation, editing, and AI-assisted development—all isolated from your host system.

## 🧩 Features

- Based on `node:24-alpine` (lightweight and fast)
- POSIX-compliant shell (`bash`) preinstalled
- Persistent volume for your local project
- Automatic installation of `@anthropic-ai/claude-code`
- Fully interactive shell session

## 🛠️ Setup

### 1. Prepare your project directory
Navigate to the project you want to use with Claude:
```bash
cd Path/To/Directory
```

### 2. Copy the following files into the project root

#### `Dockerfile`

```dockerfile
FROM node:24-alpine
RUN apk add --no-cache bash
ENV SHELL=/bin/bash NODE_ENV=development
WORKDIR /workspace
RUN npm install -g @anthropic-ai/claude-code
CMD ["/bin/bash"]
```

#### `docker-compose.yml`

```yaml
services:
  claude:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: claude
    working_dir: /workspace
    volumes:
      - Path/To/Directory:/workspace
    tty: true
    stdin_open: true
    environment:
      - SHELL=/bin/bash
```

---

## ⚙️ Usage

### Build the image

```bash
docker compose build
```

### Start an interactive session

```bash
docker compose run claude
```

You’ll drop into a bash shell inside the container.

Then start Claude:

```bash
claude
```

### Restart after exit

```bash
docker start -ai claude
```

---

## 📁 Folder Mapping

Your local project directory:

```
Path/To/Directory
```

is mounted inside the container as

```
/workspace
```

Any file changes in either location are synchronized automatically.

---

## 🧹 Cleanup

Remove container and image:

```bash
docker compose down --rmi all
```

---

## 🧠 Notes

* The `$SHELL` environment variable ensures Claude detects a valid POSIX shell.
* `bash` is minimal but sufficient for all Claude CLI operations.
* No data is stored outside the mounted volume.

---

## 🧩 Commands Summary

| Command                         | Description                     |
| ------------------------------- | ------------------------------- |
| `docker compose build`          | Build the Docker image          |
| `docker compose run claude`     | Start an interactive container  |
| `claude`                        | Launch the Claude CLI           |
| `docker start -ai claude`       | Reattach to a stopped container |
| `docker compose down --rmi all` | Clean up everything             |

---

### ✅ Result

After following these steps, you can run `claude` inside the container, and it will have full shell access and persistent project files.

