FROM node:24-alpine

RUN apk add --no-cache \
    bash \
    bubblewrap \
    ca-certificates \
    coreutils \
    curl \
    docker-cli \
    docker-cli-compose \
    findutils \
    git \
    jq \
    less \
    make \
    openssh-client \
    procps \
    py3-pip \
    py3-pytest \
    py3-pytest-cov \
    python3 \
    ripgrep \
    shadow \
    su-exec \
    vim \
    ruff

## Optional: native build toolchain for Python/Node packages that compile extensions.
# RUN apk add --no-cache build-base linux-headers

ENV SHELL=/bin/bash \
    NODE_ENV=development \
    USE_BUILTIN_RIPGREP=0 \
    AGENT_USER=agent

RUN addgroup -g 1001 agent && \
    adduser -D -u 1001 -G agent -h /home/agent agent

WORKDIR /workspace

## Install your preferred AI CLI tool (rebuild after changing):
RUN npm install -g @anthropic-ai/claude-code
# RUN npm install -g @openai/codex
# RUN npm install -g @google/gemini-cli

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]
