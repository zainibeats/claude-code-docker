## 1. Base image: lightweight Node.js 24 on Alpine
FROM node:24-alpine

## 2. Install essential tools (uncomment or add tools as needed)
RUN apk add --no-cache \
    bash \
    git \
    curl \
    wget \
    # openssh-client \
    ## Common build tools that projects might need (uncomment or add tools as needed)
    python3 \
    # make \
    # g++ \
    ## Docker CLI (if you want the agent to interact with Docker)
    docker-cli

## 3. Set environment variables
ENV SHELL=/bin/bash \
    NODE_ENV=development \
    TERM=xterm-256color

## 4. Create a non-root user for better security (optional but recommended)
RUN addgroup -g 1001 claude && \
    adduser -D -u 1001 -G claude claude

## 5. Set working directory inside the container
WORKDIR /workspace

## 6. Install Claude Code CLI globally - Replace with desired cli agent
RUN npm install -g @anthropic-ai/claude-code

## 7. Set ownership of workspace (if using non-root user)
RUN chown -R claude:claude /workspace

## 8. Switch to non-root user (optional)
USER claude

## 9. Default command: start bash shell
CMD ["/bin/bash"]
