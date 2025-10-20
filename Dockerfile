# 1. Base image: lightweight Node.js 24 on Alpine
FROM node:24-alpine

# 2. Install bash for POSIX shell compatibility
RUN apk add --no-cache bash

# 3. Set environment variables
ENV SHELL=/bin/bash \
    NODE_ENV=development

# 4. Set working directory inside the container
WORKDIR /workspace

# 5. Install Claude Code CLI globally
RUN npm install -g @anthropic-ai/claude-code

# 6. Default command: start bash shell
CMD ["/bin/bash"]
