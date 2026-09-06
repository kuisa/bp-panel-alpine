#!/bin/sh
# Alpine Linux browser-panel runtime installer
# Installs:
#   Chromium + matching chromedriver
#   Xvfb + Xauth + xdotool + screenshots
#   Python3 + pip + build toolchain
#   Node.js + npm
#   ffmpeg + CJK/emoji fonts
#   DrissionPage / Selenium / SeleniumBase / Playwright
#   Pyrogram / TgCrypto / SpeechRecognition / pydub / numpy / Pillow
#
# Designed for Alpine Linux 3.20+ / 3.21+ / 3.22+ / 3.23+ / 3.24+.
# Does NOT use systemd. Xvfb is managed with OpenRC when available,
# otherwise it is started directly for containers/minimal environments.

set -eu

ROOT="${PANEL_ROOT:-/opt/browser-panel}"
ENV_FILE="${PANEL_ENV:-$ROOT/.env.panel}"
BROWSER_USER="${BROWSER_USER:-browser}"
BROWSER_HOME="${BROWSER_HOME:-/home/$BROWSER_USER}"
BROWSER_WORK="${BROWSER_WORK_DIR:-$BROWSER_HOME/browser-work}"
DISPLAY_NUM="${BROWSER_DISPLAY:-:1}"
CHROME_PATH="/usr/bin/chromium-browser"
CHROMEDRIVER_PATH="/usr/bin/chromedriver"

log() {
    echo "[install-browser-stack-alpine] $*"
}

die() {
    echo "[install-browser-stack-alpine] ERROR: $*" >&2
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
if [ ! -f /etc/alpine-release ] || ! have apk; then
    die "This installer is for Alpine Linux only."
fi

ALPINE_VERSION="$(cat /etc/alpine-release)"
ARCH="$(uname -m)"
log "Alpine $ALPINE_VERSION / arch=$ARCH"

# ---------------------------------------------------------------------------
# APK repositories
# ---------------------------------------------------------------------------
log "Enabling Alpine community repository"

if [ -f /etc/apk/repositories ]; then
    # Keep the current Alpine branch. Add community if it is missing.
    if ! grep -Eq '^[[:space:]]*[^#].*/community/?[[:space:]]*$' /etc/apk/repositories; then
        BRANCH="$(echo "$ALPINE_VERSION" | cut -d. -f1,2)"
        echo "https://dl-cdn.alpinelinux.org/alpine/v${BRANCH}/community" >> /etc/apk/repositories
        log "Added community repository for v${BRANCH}"
    fi
fi

apk update

# ---------------------------------------------------------------------------
# Base packages
# ---------------------------------------------------------------------------
# chromium itself pulls its required GTK/NSS/X11/mesa libraries.
# chromium-chromedriver is deliberately installed from the SAME Alpine repo
# so the driver matches the installed Chromium package.
log "Installing Alpine base/browser packages"

apk add --no-cache \
    ca-certificates \
    curl \
    wget \
    unzip \
    tar \
    gzip \
    bash \
    coreutils \
    findutils \
    grep \
    sed \
    procps \
    shadow \
    su-exec \
    build-base \
    linux-headers \
    python3 \
    python3-dev \
    python3-tkinter \
    py3-pip \
    py3-setuptools \
    py3-wheel \
    nodejs \
    npm \
    chromium \
    chromium-chromedriver \
    xvfb \
    xauth \
    xdotool \
    scrot \
    ffmpeg \
    fontconfig \
    font-noto \
    font-noto-cjk \
    font-noto-emoji \
    dbus-libs \
    libstdc++ \
    tzdata

# Some Alpine releases use different names/availability for the extra font
# packages. They are optional because Chromium already has its core fonts.
apk add --no-cache font-opensans 2>/dev/null || true

fc-cache -f >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# Verify Chromium and chromedriver
# ---------------------------------------------------------------------------
if [ -x /usr/bin/chromium-browser ]; then
    CHROME_PATH="/usr/bin/chromium-browser"
elif [ -x /usr/bin/chromium ]; then
    CHROME_PATH="/usr/bin/chromium"
else
    die "Chromium binary was not installed."
fi

if [ -x /usr/bin/chromedriver ]; then
    CHROMEDRIVER_PATH="/usr/bin/chromedriver"
elif [ -x /usr/lib/chromium/chromedriver ]; then
    CHROMEDRIVER_PATH="/usr/lib/chromium/chromedriver"
else
    die "chromedriver was not installed."
fi

log "Chromium: $CHROME_PATH"
"$CHROME_PATH" --version || die "Chromium cannot execute"

log "Chromedriver: $CHROMEDRIVER_PATH"
"$CHROMEDRIVER_PATH" --version || die "chromedriver cannot execute"

# ---------------------------------------------------------------------------
# Node.js / npm
# ---------------------------------------------------------------------------
have node || die "Node.js installation failed"
have npm || die "npm installation failed"

NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)"
[ "$NODE_MAJOR" -ge 18 ] || die "Node.js >= 18 is required; found $(node -v)"

log "Node.js $(node -v)"
log "npm $(npm -v)"

# ---------------------------------------------------------------------------
# Browser user + directories
# ---------------------------------------------------------------------------
if ! id "$BROWSER_USER" >/dev/null 2>&1; then
    log "Creating user: $BROWSER_USER"
    adduser -D -h "$BROWSER_HOME" -s /bin/bash "$BROWSER_USER"
fi

mkdir -p \
    "$ROOT" \
    "$BROWSER_HOME" \
    "$BROWSER_WORK/persistent" \
    "$BROWSER_WORK/profiles" \
    "$BROWSER_WORK/screenshots" \
    "$BROWSER_WORK/task-results" \
    "$BROWSER_WORK/downloaded_files" \
    "$BROWSER_WORK/assets" \
    "$BROWSER_WORK/archived_files"

chown -R "$BROWSER_USER:$BROWSER_USER" "$BROWSER_HOME" "$BROWSER_WORK"
chmod -R a+rX "$BROWSER_WORK" 2>/dev/null || true

# ---------------------------------------------------------------------------
# .env.panel
# ---------------------------------------------------------------------------
set_kv() {
    key="$1"
    value="$2"
    mkdir -p "$(dirname "$ENV_FILE")"
    touch "$ENV_FILE"

    if grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
    else
        printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    fi
}

set_kv_if_missing() {
    key="$1"
    value="$2"
    mkdir -p "$(dirname "$ENV_FILE")"
    touch "$ENV_FILE"

    if ! grep -q "^${key}=" "$ENV_FILE" 2>/dev/null; then
        printf '%s=%s\n' "$key" "$value" >> "$ENV_FILE"
    fi
}

log "Writing $ENV_FILE"

set_kv_if_missing PORT "3210"
set_kv_if_missing HOST "0.0.0.0"
set_kv BROWSER_DISPLAY "$DISPLAY_NUM"
set_kv BROWSER_CHROME_PATH "$CHROME_PATH"
set_kv PLAYWRIGHT_CHROME_PATH "$CHROME_PATH"
set_kv BROWSER_USER "$BROWSER_USER"
set_kv BROWSER_HOME "$BROWSER_HOME"
set_kv BROWSER_WORK_DIR "$BROWSER_WORK"
set_kv BROWSER_XAUTHORITY "$BROWSER_HOME/.Xauthority"
set_kv BROWSER_USER_DATA_DIR "$BROWSER_WORK/persistent"

# Do not let Playwright download another browser.
set_kv PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD "1"
set_kv PLAYWRIGHT_BROWSERS_PATH "0"

# Useful for Chromium/automation environments.
set_kv_if_missing CHROMEDRIVER_PATH "$CHROMEDRIVER_PATH"

# ---------------------------------------------------------------------------
# Python / pip
# ---------------------------------------------------------------------------
have python3 || die "python3 installation failed"
python3 -m pip --version >/dev/null 2>&1 || die "pip installation failed"

log "Python $(python3 --version 2>&1)"
log "pip $(python3 -m pip --version)"

PIP_INSTALL="
python3 -m pip install
--break-system-packages
--ignore-installed
--disable-pip-version-check
--no-cache-dir
"

# Alpine uses musl, so wheels are preferred. If a package has to compile,
# build-base/python3-dev/linux-headers are already installed above.
log "Installing Python build helpers"
# shellcheck disable=SC2086
$PIP_INSTALL -U setuptools wheel

# Include panel requirement files if they already exist.
REQUIREMENT_ARGS=""
for requirement_file in \
    "$ROOT/requirements-dp.txt" \
    "$ROOT/requirements-sb.txt" \
    "$ROOT/requirements-playwright.txt"
do
    if [ -f "$requirement_file" ]; then
        REQUIREMENT_ARGS="$REQUIREMENT_ARGS -r $requirement_file"
    fi
done

log "Installing Python browser/task stack"

# shellcheck disable=SC2086
$PIP_INSTALL -U \
    $REQUIREMENT_ARGS \
    "requests>=2.31.0" \
    "urllib3>=2.0.0" \
    "Pillow>=10.0.0" \
    "DrissionPage>=4.1.0" \
    "selenium>=4.20.0" \
    "seleniumbase>=4.30.0" \
    "playwright>=1.40.0" \
    "pyrogram>=2.0.0" \
    "TgCrypto>=1.2.0" \
    "SpeechRecognition>=3.10.0" \
    "pydub>=0.25.0" \
    "numpy>=1.24.0"

# ---------------------------------------------------------------------------
# Python import verification
# ---------------------------------------------------------------------------
log "Verifying Python runtime"

python3 - <<'PY'
import importlib
import sys

modules = [
    "DrissionPage",
    "seleniumbase",
    "selenium",
    "playwright",
    "pyrogram",
    "PIL",
    "requests",
    "urllib3",
    "speech_recognition",
    "pydub",
    "numpy",
]

failed = []

for name in modules:
    try:
        importlib.import_module(name)
    except Exception as exc:
        failed.append(f"{name}: {exc}")

if failed:
    print("Python runtime verification failed:", file=sys.stderr)
    for item in failed:
        print("  - " + item, file=sys.stderr)
    raise SystemExit(1)

print("Python runtime imports: OK")
PY

# ---------------------------------------------------------------------------
# Playwright: do NOT download its browser.
# The application must use:
#   executable_path=/usr/bin/chromium-browser
# or the BROWSER_CHROME_PATH / PLAYWRIGHT_CHROME_PATH value above.
# ---------------------------------------------------------------------------
export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
export PLAYWRIGHT_BROWSERS_PATH=0

# Verify Playwright Python package without downloading a browser.
python3 - <<'PY'
from playwright.sync_api import sync_playwright

with sync_playwright() as p:
    print("Playwright Python package: OK")
PY

# ---------------------------------------------------------------------------
# Selenium: Alpine's chromium-chromedriver is the matching system driver.
# Do NOT use SeleniumBase's downloader here because it can fetch a second
# driver/browser from the internet and break the "single system Chromium"
# design.
# ---------------------------------------------------------------------------
log "Using system chromedriver: $CHROMEDRIVER_PATH"

# ---------------------------------------------------------------------------
# Xvfb
# ---------------------------------------------------------------------------
XAUTH_FILE="$BROWSER_HOME/.Xauthority"

start_xvfb() {
    if pgrep -f "[X]vfb $DISPLAY_NUM" >/dev/null 2>&1; then
        log "Xvfb $DISPLAY_NUM is already running"
        return 0
    fi

    rm -f "$XAUTH_FILE" 2>/dev/null || true
    touch "$XAUTH_FILE"
    chown "$BROWSER_USER:$BROWSER_USER" "$XAUTH_FILE"

    log "Starting Xvfb $DISPLAY_NUM"

    # -ac means X access control is disabled. This mirrors the original
    # installer and is suitable for a dedicated browser automation host.
    Xvfb "$DISPLAY_NUM" \
        -screen 0 1440x900x24 \
        -ac \
        +extension GLX \
        +render \
        -noreset \
        >/var/log/xvfb-browser.log 2>&1 &

    XVFB_PID=$!

    sleep 1

    if ! kill -0 "$XVFB_PID" 2>/dev/null; then
        cat /var/log/xvfb-browser.log >&2 || true
        die "Xvfb failed to start"
    fi

    log "Xvfb started: PID=$XVFB_PID DISPLAY=$DISPLAY_NUM"
}

# ---------------------------------------------------------------------------
# OpenRC service, when OpenRC is available.
# ---------------------------------------------------------------------------
install_openrc_service() {
    if ! have rc-service || ! have rc-update; then
        return 0
    fi

    mkdir -p /etc/init.d

    cat >/etc/init.d/xvfb-browser <<'EOF'
#!/sbin/openrc-run

name="xvfb-browser"
description="Permanent Xvfb display for browser automation"

command="/usr/bin/Xvfb"
command_args=":1 -screen 0 1440x900x24 -ac +extension GLX +render -noreset"
command_background="yes"
pidfile="/run/xvfb-browser.pid"

depend() {
    need localmount
    after bootmisc
}
EOF

    chmod +x /etc/init.d/xvfb-browser

    rc-update add xvfb-browser default >/dev/null 2>&1 || true

    if rc-service xvfb-browser status >/dev/null 2>&1; then
        rc-service xvfb-browser restart >/dev/null 2>&1 || true
    else
        rc-service xvfb-browser start >/dev/null 2>&1 || true
    fi

    sleep 1

    if pgrep -f "[X]vfb :1" >/dev/null 2>&1; then
        log "OpenRC Xvfb service is active"
    else
        log "WARN: OpenRC service was installed but Xvfb is not running"
    fi
}

# Prefer OpenRC on an Alpine VPS. In a container/minimal environment,
# there may be no init system, so start Xvfb directly.
if have rc-service && [ -d /run/openrc ] || [ -f /sbin/openrc ]; then
    install_openrc_service
else
    start_xvfb
fi

# Make X environment available to browser tasks launched by this shell.
export DISPLAY="$DISPLAY_NUM"
export XAUTHORITY="$XAUTH_FILE"

# ---------------------------------------------------------------------------
# Final Chromium smoke test
# ---------------------------------------------------------------------------
log "Running Chromium smoke test"

TMP_PROFILE="$(mktemp -d /tmp/chromium-test.XXXXXX)"
trap 'rm -rf "$TMP_PROFILE" 2>/dev/null || true' EXIT

if "$CHROME_PATH" \
    --headless=new \
    --no-sandbox \
    --disable-dev-shm-usage \
    --disable-gpu \
    --user-data-dir="$TMP_PROFILE" \
    --dump-dom \
    about:blank >/dev/null 2>&1
then
    log "Chromium headless smoke test: OK"
else
    log "WARN: headless Chromium test failed; testing Xvfb mode"

    if DISPLAY="$DISPLAY_NUM" "$CHROME_PATH" \
        --no-sandbox \
        --disable-dev-shm-usage \
        --disable-gpu \
        --user-data-dir="$TMP_PROFILE" \
        --dump-dom \
        about:blank >/dev/null 2>&1
    then
        log "Chromium Xvfb smoke test: OK"
    else
        die "Chromium could not start. Check /var/log/xvfb-browser.log and run: $CHROME_PATH --version"
    fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo
log "========================================"
log " Alpine browser stack installation done"
log "========================================"
echo "Alpine:          $ALPINE_VERSION"
echo "Architecture:    $ARCH"
echo "Chromium:        $CHROME_PATH"
echo "Chromedriver:    $CHROMEDRIVER_PATH"
echo "Node:             $(node -v)"
echo "npm:              $(npm -v)"
echo "Python:           $(python3 --version 2>&1)"
echo "Display:          $DISPLAY_NUM"
echo "Browser user:     $BROWSER_USER"
echo "Work dir:         $BROWSER_WORK"
echo "Env file:         $ENV_FILE"
echo

if pgrep -f "[X]vfb" >/dev/null 2>&1; then
    echo "Xvfb:             RUNNING"
else
    echo "Xvfb:             NOT RUNNING"
fi

echo
echo "Browser path for panel:"
echo "  $CHROME_PATH"
echo
echo "Playwright browser download:"
echo "  DISABLED (system Chromium is used)"
echo
echo "Notes:"
echo "  - Alpine/OpenRC is used instead of systemd."
echo "  - chromium + chromium-chromedriver come from Alpine packages."
echo "  - No Google Chrome .deb is used."
echo "  - No Playwright browser is downloaded."
echo "  - Python packages are installed system-wide."
echo "  - Existing $ENV_FILE values are preserved where possible."
echo
