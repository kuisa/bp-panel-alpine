#!/bin/sh
# Alpine Linux version of browser-panel bp.sh
# One command: fresh install or upgrade in place, preserve user data,
# install npm dependencies, configure OpenRC services, and restart the panel.
#
# Usage:
#   sh bp-alpine.sh
#   or:
#   curl -fsSL https://raw.githubusercontent.com/debbide/browser-panel/master/scripts/bp-alpine.sh | sh
#
# Expected runtime:
#   - Alpine Linux
#   - Node.js >= 18
#   - Python3
#   - Chromium/Xvfb stack installed by install-browser-stack-alpine.sh
#
# Unlike the Debian version, this script DOES NOT use systemd.

set -eu

REPO="${GITHUB_REPO:-debbide/browser-panel}"
ROOT="${PANEL_ROOT:-/opt/browser-panel}"
SERVICE="${SERVICE_NAME:-browser-automation-panel}"
XVFB_SERVICE="${XVFB_SERVICE:-xvfb-browser}"
BROWSER_USER="${BROWSER_USER:-browser}"

log() {
    echo "[bp-alpine] $*"
}

die() {
    echo "[bp-alpine] ERROR: $*" >&2
    exit 1
}

need_root() {
    [ "$(id -u)" -eq 0 ] || die "run as root: sh $0"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

need_root

# ---------------------------------------------------------------------------
# Alpine check
# ---------------------------------------------------------------------------
[ -f /etc/alpine-release ] || die "this installer requires Alpine Linux"

have apk || die "apk not found"

# ---------------------------------------------------------------------------
# Required host tools
# ---------------------------------------------------------------------------
# bp.sh itself should remain lightweight. Install only tools needed to
# download/extract/upgrade the panel. Browser/Python runtime belongs to the
# separate install-browser-stack-alpine.sh.
log "checking host dependencies"

if ! have curl || ! have tar || ! have node || ! have python3 || ! have npm; then
    log "installing missing Alpine base tools"
    apk add --no-cache \
        ca-certificates \
        curl \
        tar \
        gzip \
        python3 \
        nodejs \
        npm
fi

have curl || die "need curl"
have tar || die "need tar"
have node || die "need Node.js >= 18"
have npm || die "need npm"
have python3 || die "need python3"

NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)"
[ "$NODE_MAJOR" -ge 18 ] || die "Node.js >= 18 required; found $(node -v)"

log "Node.js $(node -v)"
log "npm $(npm -v)"

# ---------------------------------------------------------------------------
# OpenRC check
# ---------------------------------------------------------------------------
# Alpine normally has OpenRC on a VPS. Containers may not.
HAS_OPENRC=0
if have rc-service && have rc-update; then
    HAS_OPENRC=1
fi

# ---------------------------------------------------------------------------
# Resolve latest release tag
# ---------------------------------------------------------------------------
resolve_tag() {
    json=""
    tag=""

    json="$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null || true)"

    if [ -n "$json" ]; then
        tag="$(printf '%s' "$json" | python3 -c \
            'import json,sys; print(json.load(sys.stdin).get("tag_name") or "")' \
            2>/dev/null || true)"

        if [ -z "$tag" ]; then
            tag="$(printf '%s' "$json" |
                sed -n 's/.*"tag_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' |
                head -1)"
        fi
    fi

    printf '%s\n' "$tag"
}

# ---------------------------------------------------------------------------
# Preserve user-owned files
# ---------------------------------------------------------------------------
preserve() {
    case "$1" in
        tasks|data|logs|screenshots|runtime-data|node_modules|.venv|.git|.env|.env.panel|.env.local)
            return 0
            ;;
        .env*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# Merge tasks/lib
# ---------------------------------------------------------------------------
merge_tasks_lib() {
    src="$1/tasks/lib"
    dst="$ROOT/tasks/lib"

    if [ ! -d "$src" ]; then
        log "no tasks/lib in package (skip merge)"
        return 0
    fi

    mkdir -p "$dst"

    # Do not use --delete: user-created helper files must survive upgrades.
    # cp -a overlays files shipped by the panel while keeping extra files.
    cp -a "$src"/. "$dst"/

    log "merged tasks/lib -> $dst"
}

# ---------------------------------------------------------------------------
# Download and merge panel
# ---------------------------------------------------------------------------
download_and_merge() {
    tag="$(resolve_tag || true)"
    tmp="$(mktemp -d)"

    cleanup() {
        rm -rf "$tmp"
    }
    trap cleanup EXIT INT TERM

    if [ -n "$tag" ]; then
        log "release $tag"

        if ! curl -fsSL \
            "https://codeload.github.com/${REPO}/tar.gz/refs/tags/${tag}" \
            -o "$tmp/src.tgz"
        then
            curl -fsSL \
                "https://github.com/${REPO}/archive/refs/tags/${tag}.tar.gz" \
                -o "$tmp/src.tgz"
        fi
    else
        log "no release tag, use master"
        curl -fsSL \
            "https://codeload.github.com/${REPO}/tar.gz/refs/heads/master" \
            -o "$tmp/src.tgz"
    fi

    mkdir -p "$tmp/tree"
    tar -xzf "$tmp/src.tgz" -C "$tmp/tree" --strip-components=1

    [ -f "$tmp/tree/package.json" ] || die "bad archive: package.json missing"

    mkdir -p "$ROOT"

    if [ -f "$ROOT/package.json" ]; then
        log "upgrade in place (keep tasks/data; merge tasks/lib)"

        # POSIX sh equivalent of the original bash dotglob/nullglob loop.
        for p in "$tmp/tree"/* "$tmp/tree"/.[!.]* "$tmp/tree"/..?*; do
            [ -e "$p" ] || continue

            n="$(basename "$p")"
            preserve "$n" && continue

            if [ -d "$p" ]; then
                rm -rf "$ROOT/$n"
                cp -a "$p" "$ROOT/$n"
            else
                cp -a "$p" "$ROOT/$n"
            fi
        done

        merge_tasks_lib "$tmp/tree"
    else
        log "fresh install -> $ROOT"

        for p in "$tmp/tree"/* "$tmp/tree"/.[!.]* "$tmp/tree"/..?*; do
            [ -e "$p" ] || continue
            n="$(basename "$p")"

            # Never blindly copy the archive's git metadata.
            [ "$n" = ".git" ] && continue

            cp -a "$p" "$ROOT/$n"
        done
    fi

    mkdir -p \
        "$ROOT/tasks" \
        "$ROOT/data" \
        "$ROOT/logs" \
        "$ROOT/screenshots" \
        "$ROOT/runtime-data" \
        "$ROOT/tasks/lib"

    if [ -n "$tag" ]; then
        printf '{"tag":"%s","ref":"%s","source":"release"}\n' \
            "$tag" "$tag" > "$ROOT/data/version.json"
    else
        printf '{"tag":null,"ref":"master","source":"master"}\n' \
            > "$ROOT/data/version.json"
    fi

    trap - EXIT INT TERM
    cleanup
}

# ---------------------------------------------------------------------------
# npm dependencies
# ---------------------------------------------------------------------------
install_deps() {
    cd "$ROOT"

    [ -f package.json ] || die "$ROOT/package.json not found"

    log "npm install --omit=dev"

    # Keep the same behavior as the original panel installer.
    # If package-lock.json exists, npm ci is tempting, but npm install is kept
    # intentionally because upgrades may change package-lock/package metadata.
    npm install --omit=dev

    # The browser stack script owns Python dependencies.
    # Do NOT create a venv or run pip here.
}

# ---------------------------------------------------------------------------
# Browser user / permissions
# ---------------------------------------------------------------------------
prepare_runtime() {
    if ! id "$BROWSER_USER" >/dev/null 2>&1; then
        log "creating user $BROWSER_USER"
        adduser -D -h "/home/$BROWSER_USER" -s /bin/bash "$BROWSER_USER"
    fi

    mkdir -p \
        "/home/$BROWSER_USER" \
        "/home/$BROWSER_USER/browser-work" \
        "$ROOT/data" \
        "$ROOT/logs" \
        "$ROOT/screenshots" \
        "$ROOT/runtime-data"

    chown -R "$BROWSER_USER:$BROWSER_USER" \
        "/home/$BROWSER_USER" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# OpenRC: Xvfb
# ---------------------------------------------------------------------------
install_xvfb_openrc() {
    [ "$HAS_OPENRC" -eq 1 ] || return 0

    # If the browser-stack installer already installed this service, leave
    # its richer configuration alone. Otherwise create a minimal one.
    if [ ! -f "/etc/init.d/$XVFB_SERVICE" ]; then
        log "creating OpenRC service: $XVFB_SERVICE"

        cat >"/etc/init.d/$XVFB_SERVICE" <<'EOF'
#!/sbin/openrc-run

name="xvfb-browser"
description="Xvfb virtual display for browser automation"

command="/usr/bin/Xvfb"
command_args=":1 -screen 0 1440x900x24 -ac +extension GLX +render -noreset"
command_background="yes"
pidfile="/run/xvfb-browser.pid"

depend() {
    need localmount
    after bootmisc
}
EOF

        chmod +x "/etc/init.d/$XVFB_SERVICE"
    fi

    rc-update add "$XVFB_SERVICE" default >/dev/null 2>&1 || true

    if rc-service "$XVFB_SERVICE" status >/dev/null 2>&1; then
        log "restart $XVFB_SERVICE"
        rc-service "$XVFB_SERVICE" restart >/dev/null 2>&1 || true
    else
        log "start $XVFB_SERVICE"
        rc-service "$XVFB_SERVICE" start >/dev/null 2>&1 || true
    fi
}

# ---------------------------------------------------------------------------
# OpenRC: Browser Panel
# ---------------------------------------------------------------------------
install_panel_openrc() {
    [ "$HAS_OPENRC" -eq 1 ] || return 0

    node_bin="$(command -v node)"
    unit="/etc/init.d/$SERVICE"

    log "install/update OpenRC service: $SERVICE"

    cat >"$unit" <<EOF
#!/sbin/openrc-run

name="browser-automation-panel"
description="Browser Automation Panel"

command="$node_bin"
command_args="$ROOT/server/index.js"
command_cwd="$ROOT"
command_background="yes"
pidfile="/run/$SERVICE.pid"

export PORT="3210"
export BROWSER_DISPLAY=":1.0"
export BROWSER_USER="$BROWSER_USER"
export BROWSER_HOME="/home/$BROWSER_USER"
export BROWSER_WORK_DIR="/home/$BROWSER_USER/browser-work"

depend() {
    need net
    after \$XVFB_SERVICE
}

start_pre() {
    if [ -f "$ROOT/.env.panel" ]; then
        # OpenRC cannot directly parse dotenv files as shell code safely.
        # The panel itself should load .env.panel; environment values above
        # are only defaults.
        :
    fi

    cd "$ROOT"
}
EOF

    chmod +x "$unit"

    # Ensure the panel sees .env.panel if the application reads it itself.
    # Most Node panel versions use dotenv; no shell-sourcing is performed here
    # because values may contain characters that are unsafe for eval.
    rc-update add "$SERVICE" default >/dev/null 2>&1 || true

    if rc-service "$SERVICE" status >/dev/null 2>&1; then
        log "restart $SERVICE"
        rc-service "$SERVICE" restart
    else
        log "start $SERVICE"
        rc-service "$SERVICE" start
    fi
}

# ---------------------------------------------------------------------------
# Non-OpenRC / container fallback
# ---------------------------------------------------------------------------
start_panel_without_init() {
    log "no OpenRC detected"

    # Start Xvfb if it isn't already running.
    if ! pgrep -f "[X]vfb :1" >/dev/null 2>&1; then
        if have Xvfb; then
            log "starting Xvfb :1 in background"
            Xvfb :1 \
                -screen 0 1440x900x24 \
                -ac \
                +extension GLX \
                +render \
                -noreset \
                >/var/log/xvfb-browser.log 2>&1 &
        fi
    fi

    log "starting panel in background"

    if [ -f "$ROOT/.env.panel" ]; then
        # Node panel normally loads .env.panel itself.
        # Keep stdout/stderr in a persistent log for container deployments.
        (
            cd "$ROOT"
            export DISPLAY="${BROWSER_DISPLAY:-:1.0}"
            export NODE_ENV="${NODE_ENV:-production}"
            exec node server/index.js
        ) >>"$ROOT/logs/panel.log" 2>&1 &
    else
        (
            cd "$ROOT"
            export DISPLAY="${BROWSER_DISPLAY:-:1.0}"
            export NODE_ENV="${NODE_ENV:-production}"
            exec node server/index.js
        ) >>"$ROOT/logs/panel.log" 2>&1 &
    fi

    log "panel started without init system; PID=$!"
}

# ---------------------------------------------------------------------------
# Verify
# ---------------------------------------------------------------------------
verify_panel() {
    log "======== verify ========"

    echo "Root:       $ROOT"
    echo "Service:    $SERVICE"
    echo "Node:       $(node -v)"
    echo "npm:        $(npm -v)"

    if [ -f "$ROOT/data/version.json" ]; then
        echo "Version:    $(cat "$ROOT/data/version.json")"
    fi

    if [ -f "$ROOT/.env.panel" ]; then
        echo "Env file:   $ROOT/.env.panel"
    fi

    if [ "$HAS_OPENRC" -eq 1 ]; then
        echo "OpenRC:     available"

        if rc-service "$SERVICE" status >/dev/null 2>&1; then
            echo "Panel:      RUNNING"
        else
            echo "Panel:      NOT RUNNING"
            log "check: rc-service $SERVICE status"
            log "logs: tail -n 100 $ROOT/logs/panel.log"
        fi

        if rc-service "$XVFB_SERVICE" status >/dev/null 2>&1; then
            echo "Xvfb:       RUNNING"
        else
            echo "Xvfb:       NOT RUNNING"
        fi
    else
        echo "OpenRC:     not available (container/minimal mode)"

        if pgrep -f "[X]vfb :1" >/dev/null 2>&1; then
            echo "Xvfb:       RUNNING"
        else
            echo "Xvfb:       NOT RUNNING"
        fi

        if pgrep -f "[n]ode $ROOT/server/index.js" >/dev/null 2>&1; then
            echo "Panel:      RUNNING"
        else
            echo "Panel:      NOT DETECTED"
        fi
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
log "root=$ROOT"
log "repo=$REPO"
log "alpine=$(cat /etc/alpine-release)"

prepare_runtime
download_and_merge
install_deps

# Browser stack is expected to have been installed separately.
# If Chromium exists, record the path for convenience.
if [ -x /usr/bin/chromium-browser ]; then
    log "Chromium detected: /usr/bin/chromium-browser"
elif [ -x /usr/bin/chromium ]; then
    log "Chromium detected: /usr/bin/chromium"
else
    log "WARN: Chromium not found; run install-browser-stack-alpine.sh"
fi

if [ "$HAS_OPENRC" -eq 1 ]; then
    install_xvfb_openrc
    install_panel_openrc
else
    start_panel_without_init
fi

verify_panel

log "done"
