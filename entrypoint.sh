#!/bin/bash
set -euo pipefail

HOST_UID="${HOST_UID:-1000}"
HOST_GID="${HOST_GID:-$HOST_UID}"
AGENT_USER="${AGENT_USER:-agent}"
AGENT_SUDO="${AGENT_SUDO:-1}"

## The image always bakes in a user literally named "agent" with this home dir.
## AGENT_USER renames it; the home path stays put so a persistent volume mounted
## at /home/agent keeps working regardless of the chosen name.
BASE_USER=agent
AGENT_HOME=/home/agent

log() { printf 'contagent: %s\n' "$*" >&2; }

## Pick an unused id well above the normal range, for shuffling a colliding
## account out of the way before we claim its uid/gid for the agent.
next_free_id() {
    local kind="$1" id=60000
    while :; do
        if [ "$kind" = uid ]; then
            getent passwd "$id" >/dev/null || { echo "$id"; return; }
        else
            getent group "$id" >/dev/null || { echo "$id"; return; }
        fi
        id=$((id + 1))
    done
}

[ "$#" -gt 0 ] || set -- /bin/bash

if [ "$HOST_UID" = "0" ]; then
    log "HOST_UID=0, running as root. Agent CLIs that refuse to run as root (e.g."
    log "claude --dangerously-skip-permissions) will not start; set HOST_UID/HOST_GID"
    log "to your host user instead (id -u / id -g)."
    exec "$@"
fi

## gosu switches uid but leaves the environment alone, so HOME has to be set
## here for everything downstream (git config --global, agent credentials).
export HOME="$AGENT_HOME"

## Apply AGENT_USER as a rename of the baked-in account.
if [ "$AGENT_USER" != "$BASE_USER" ] && ! getent passwd "$AGENT_USER" >/dev/null; then
    groupmod -n "$AGENT_USER" "$BASE_USER"
    usermod -l "$AGENT_USER" -d "$AGENT_HOME" "$BASE_USER"
fi

if ! getent passwd "$AGENT_USER" >/dev/null; then
    log "no such user: $AGENT_USER"
    exit 1
fi

## Match the container user to the host user so bind-mounted files keep their
## ownership. Any pre-existing account holding the target uid/gid is moved aside
## -- node:24 ships a "node" user at 1000:1000, which is exactly the id most
## hosts hand us.
PRIMARY_GROUP="$(id -gn "$AGENT_USER")"
if [ "$(id -g "$AGENT_USER")" != "$HOST_GID" ]; then
    CONFLICT="$(getent group "$HOST_GID" | cut -d: -f1 || true)"
    if [ -n "$CONFLICT" ] && [ "$CONFLICT" != "$PRIMARY_GROUP" ]; then
        groupmod -g "$(next_free_id gid)" "$CONFLICT"
    fi
    groupmod -g "$HOST_GID" "$PRIMARY_GROUP"
fi

if [ "$(id -u "$AGENT_USER")" != "$HOST_UID" ]; then
    CONFLICT="$(getent passwd "$HOST_UID" | cut -d: -f1 || true)"
    if [ -n "$CONFLICT" ] && [ "$CONFLICT" != "$AGENT_USER" ]; then
        usermod -u "$(next_free_id uid)" "$CONFLICT"
    fi
    usermod -u "$HOST_UID" -g "$HOST_GID" "$AGENT_USER"
fi

## Passwordless sudo: the container is the security boundary, so an agent that
## needs a missing package can install it instead of stalling. Set AGENT_SUDO=0
## to turn it off.
if [ "$AGENT_SUDO" = "0" ]; then
    rm -f /etc/sudoers.d/90-agent
else
    printf '%s ALL=(ALL) NOPASSWD:ALL\n' "$AGENT_USER" > /etc/sudoers.d/90-agent
    chmod 0440 /etc/sudoers.d/90-agent
fi

## Seed an interactive shell config on first run (the home volume starts empty
## of anything the image did not put there before the volume was created).
if [ ! -f "$AGENT_HOME/.bashrc" ] && [ -f /opt/contagent/bashrc ]; then
    cp /opt/contagent/bashrc "$AGENT_HOME/.bashrc"
fi

## Re-own anything the uid/gid remap left behind. Scoped by a predicate so a
## warm home volume with a large npm/uv cache does not get chowned every start.
find "$AGENT_HOME" \( ! -user "$AGENT_USER" -o ! -group "$PRIMARY_GROUP" \) \
    -exec chown -h "$AGENT_USER:$PRIMARY_GROUP" {} + 2>/dev/null || true

## usermod only fixes ownership under $HOME, so the out-of-home toolchain dirs
## need doing by hand.
for dir in "${VIRTUAL_ENV:-}" "${NPM_CONFIG_PREFIX:-}"; do
    if [ -n "$dir" ] && [ -d "$dir" ] && [ "$(stat -c %u "$dir")" != "$HOST_UID" ]; then
        chown -R "$AGENT_USER:$PRIMARY_GROUP" "$dir"
    fi
done

## Keep /workspace working as a shorthand when the workspace is bind-mounted at
## its host path (which is what makes nested `docker run -v` resolve correctly).
if [ -n "${WORKSPACE:-}" ] && [ "$WORKSPACE" != /workspace ] && [ -d "$WORKSPACE" ]; then
    [ -L /workspace ] || rmdir /workspace 2>/dev/null || true
    if [ ! -e /workspace ] || [ -L /workspace ]; then
        ln -sfn "$WORKSPACE" /workspace
    fi
fi

WORKSPACE_DIR="${WORKSPACE:-/workspace}"
if [ -d "$WORKSPACE_DIR" ] && ! gosu "$AGENT_USER" test -w "$WORKSPACE_DIR"; then
    log "warning: $WORKSPACE_DIR is not writable by $AGENT_USER."
    log "It is owned by $(stat -c '%u:%g' "$WORKSPACE_DIR") — set HOST_UID/HOST_GID"
    log "in .env to match (id -u / id -g on the host) and recreate the container."
fi

## Let agents work with bind-mounted repositories without Git ownership prompts.
gosu "$AGENT_USER" git config --global --replace-all safe.directory '*'

## Configure a container-local Git identity when provided by the Compose env.
if [ -n "${GIT_USER_NAME:-}" ]; then
    gosu "$AGENT_USER" git config --global --replace-all user.name "$GIT_USER_NAME"
fi

if [ -n "${GIT_USER_EMAIL:-}" ]; then
    gosu "$AGENT_USER" git config --global --replace-all user.email "$GIT_USER_EMAIL"
fi

## A forwarded SSH agent is how `git push` over SSH works without copying keys
## into the container. Compose mounts /dev/null when the host has no agent, so
## drop the variable rather than leave ssh pointing at a dead socket.
if [ -n "${SSH_AUTH_SOCK:-}" ] && [ ! -S "$SSH_AUTH_SOCK" ]; then
    unset SSH_AUTH_SOCK
fi

## With a token present, teach Git to use it so HTTPS pushes do not prompt.
if [ -n "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ] && command -v gh >/dev/null 2>&1; then
    gosu "$AGENT_USER" gh auth setup-git >/dev/null 2>&1 ||
        log "gh auth setup-git failed; git over HTTPS may prompt for credentials"
fi

## If the host Docker socket is mounted, make sure the agent can reach it.
if [ -S /var/run/docker.sock ] && ! gosu "$AGENT_USER" test -w /var/run/docker.sock; then
    DOCKER_GID="$(stat -c '%g' /var/run/docker.sock)"
    DOCKER_GROUP="$(getent group "$DOCKER_GID" | cut -d: -f1 || true)"

    if [ -z "$DOCKER_GROUP" ]; then
        DOCKER_GROUP=docker-host
        groupadd -g "$DOCKER_GID" "$DOCKER_GROUP"
    fi

    usermod -aG "$DOCKER_GROUP" "$AGENT_USER"
fi

exec gosu "$AGENT_USER" "$@"
