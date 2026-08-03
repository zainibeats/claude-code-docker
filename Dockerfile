# syntax=docker/dockerfile:1

## Debian rather than Alpine: glibc means prebuilt Python wheels, prebuilt native
## npm modules, and vendor-shipped binaries all work the same way they do on the
## host, and GNU grep/sed/awk/coreutils are the defaults instead of busybox.
FROM node:24-bookworm-slim

## AI CLI packages installed globally. Switch providers without editing this file:
##   AGENT_PACKAGES="@openai/codex" docker compose build
ARG AGENT_PACKAGES="@anthropic-ai/claude-code"

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      bash \
      bubblewrap \
      build-essential \
      ca-certificates \
      curl \
      diffutils \
      file \
      git \
      gnupg \
      gosu \
      htop \
      jq \
      less \
      make \
      ncurses-term \
      openssh-client \
      patch \
      procps \
      python3 \
      python3-venv \
      ripgrep \
      rsync \
      sudo \
      tar \
      tmux \
      tree \
      tzdata \
      unzip \
      vim \
      wget \
      xz-utils \
      zip \
    && rm -rf /var/lib/apt/lists/*

## Docker CLI + buildx + compose plugins, talking to the host daemon over the
## mounted socket. buildx matters: without it `docker buildx build` fails outright.
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc && \
    chmod a+r /etc/apt/keyrings/docker.asc && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
      > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y --no-install-recommends \
      docker-ce-cli \
      docker-buildx-plugin \
      docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

## GitHub CLI. Coding agents reach for `gh` constantly (PRs, issues, CI logs).
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      -o /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    chmod a+r /etc/apt/keyrings/githubcli-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list && \
    apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

## uv, for fast Python package management and one-off tool runs.
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

RUN groupadd -g 1001 agent && \
    useradd -m -u 1001 -g agent -s /bin/bash agent

## Neither Docker nor gosu derives HOME from the effective uid, so set it
## explicitly. Without this, npm/git/agent config all land in /root.
ENV HOME=/home/agent

## A shared virtualenv on PATH sidesteps PEP 668: `pip install` inside the
## container installs into /opt/venv instead of failing as externally-managed.
## Global npm prefix lives outside $HOME so image rebuilds still update it even
## when /home/agent is a persistent volume, and so the agent can self-update.
ENV VIRTUAL_ENV=/opt/venv \
    NPM_CONFIG_PREFIX=/opt/npm-global \
    PATH=/opt/venv/bin:/opt/npm-global/bin:$PATH

RUN uv venv --seed "$VIRTUAL_ENV" && \
    uv pip install --python "$VIRTUAL_ENV/bin/python" pytest pytest-cov ruff && \
    mkdir -p "$NPM_CONFIG_PREFIX" && \
    chown -R agent:agent "$VIRTUAL_ENV" "$NPM_CONFIG_PREFIX"

USER agent
RUN npm install -g $AGENT_PACKAGES
USER root

## USE_BUILTIN_RIPGREP points Claude Code at the system ripgrep above.
ENV SHELL=/bin/bash \
    LANG=C.UTF-8 \
    EDITOR=vim \
    PAGER=less \
    LESS=-R \
    AGENT_USER=agent \
    USE_BUILTIN_RIPGREP=0

COPY bashrc /opt/contagent/bashrc
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh && mkdir -p /workspace

WORKDIR /workspace

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
