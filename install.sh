#!/bin/sh

# ============================================================
# browser-panel Alpine Browser Stack Installer
# ============================================================
#
# Alpine Linux
#
# Installs:
#   - Chromium
#   - Chromium ChromeDriver
#   - Xvfb
#   - xauth
#   - xdotool
#   - scrot
#   - ffmpeg
#   - Noto fonts
#   - Python 3 + pip
#   - Node.js + npm
#   - browser-panel Python dependencies
#
# Browser:
#   /usr/bin/chromium
#
# Real Chromium ELF:
#   /usr/lib/chromium/chromium
#
# ChromeDriver:
#   /usr/bin/chromedriver
#
# Xvfb:
#   DISPLAY=:1
#
# Environment:
#   /opt/browser-panel/.env.panel
#
# ============================================================

set -eu


# ============================================================
# Configuration
# ============================================================

ROOT="${PANEL_ROOT:-/opt/browser-panel}"

ENV_FILE="${PANEL_ENV:-$ROOT/.env.panel}"

BROWSER_USER="${BROWSER_USER:-browser}"

BROWSER_HOME="${BROWSER_HOME:-/home/$BROWSER_USER}"

BROWSER_WORK="${BROWSER_WORK_DIR:-$BROWSER_HOME/browser-work}"

DISPLAY_NUM="${BROWSER_DISPLAY:-:1}"


# ============================================================
# Helpers
# ============================================================

log() {
    echo "[install-browser-stack-alpine] $*"
}

warn() {
    echo "[install-browser-stack-alpine] WARN: $*" >&2
}

die() {
    echo "[install-browser-stack-alpine] ERROR: $*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}


# ============================================================
# Root / Alpine check
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
    die "please run as root"
fi

if [ ! -f /etc/alpine-release ]; then
    die "this installer is only for Alpine Linux"
fi

if ! have apk; then
    die "apk command not found"
fi


ALPINE_VERSION="$(cat /etc/alpine-release)"
ARCH="$(uname -m)"

log "========================================"
log "Alpine Browser Stack"
log "========================================"
log "Alpine:       $ALPINE_VERSION"
log "Architecture: $ARCH"
log "Panel root:   $ROOT"
log "Browser user: $BROWSER_USER"
log "Display:      $DISPLAY_NUM"


# ============================================================
# Alpine repositories
# ============================================================

log "checking Alpine repositories"

if ! grep -q '/community' /etc/apk/repositories 2>/dev/null; then

    ALPINE_BRANCH="$(echo "$ALPINE_VERSION" | cut -d. -f1,2)"

    COMMUNITY_REPO="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_BRANCH}/community"

    echo "$COMMUNITY_REPO" >> /etc/apk/repositories

    log "added community repository:"
    log "  $COMMUNITY_REPO"

fi


# ============================================================
# apk update
# ============================================================

log "apk update"

apk update


# ============================================================
# Base packages
# ============================================================

log "installing system packages"

apk add --no-cache \
    ca-certificates \
    curl \
    wget \
    bash \
    coreutils \
    findutils \
    grep \
    sed \
    tar \
    gzip \
    unzip \
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


update-ca-certificates >/dev/null 2>&1 || true


# ============================================================
# Real Chromium ELF
# ============================================================

CHROMIUM_ELF=""

for candidate in \
    /usr/lib/chromium/chromium \
    /usr/lib/chromium/chrome
do

    if [ -x "$candidate" ]; then
        CHROMIUM_ELF="$candidate"
        break
    fi

done


if [ -z "$CHROMIUM_ELF" ]; then

    die "Chromium ELF was not installed

Expected one of:
  /usr/lib/chromium/chromium
  /usr/lib/chromium/chrome"

fi


log "Chromium launcher:"
log "  $CHROMIUM_LAUNCHER"

log "Chromium ELF:"
log "  $CHROMIUM_ELF"


# ============================================================
# Chromium version
# ============================================================

CHROMIUM_VERSION="$("$CHROMIUM_LAUNCHER" --version 2>/dev/null || true)"

if [ -z "$CHROMIUM_VERSION" ]; then
    die "Chromium launcher exists but cannot execute"
fi

log "Chromium:"
log "  $CHROMIUM_VERSION"


# ============================================================
# ChromeDriver
# ============================================================

log "detecting ChromeDriver"

CHROMEDRIVER=""

for candidate in \
    /usr/bin/chromedriver \
    /usr/lib/chromium/chromedriver
do

    if [ -x "$candidate" ]; then
        CHROMEDRIVER="$candidate"
        break
    fi

done


if [ -z "$CHROMEDRIVER" ]; then

    die "ChromeDriver was not installed

Expected:
  /usr/bin/chromedriver
  /usr/lib/chromium/chromedriver"

fi


# Prefer PATH version.
if [ -x /usr/bin/chromedriver ]; then
    CHROMEDRIVER="/usr/bin/chromedriver"
fi


CHROMEDRIVER_VERSION="$("$CHROMEDRIVER" --version 2>/dev/null || true)"

if [ -z "$CHROMEDRIVER_VERSION" ]; then
    die "ChromeDriver exists but cannot execute"
fi


log "ChromeDriver:"
log "  $CHROMEDRIVER"

log "Driver version:"
log "  $CHROMEDRIVER_VERSION"


# ============================================================
# Node.js
# ============================================================

log "checking Node.js"

if ! have node; then
    die "Node.js installation failed"
fi

if ! have npm; then
    die "npm installation failed"
fi


NODE_MAJOR="$(
    node -p 'Number(process.versions.node.split(".")[0])' \
    2>/dev/null || echo 0
)"


case "$NODE_MAJOR" in
    ''|*[!0-9]*)
        die "cannot determine Node.js version"
        ;;
esac


if [ "$NODE_MAJOR" -lt 18 ]; then
    die "Node.js >= 18 required; found $(node -v)"
fi


log "Node:"
log "  $(node -v)"

log "npm:"
log "  $(npm -v)"


# ============================================================
# Python
# ============================================================

if ! have python3; then
    die "python3 installation failed"
fi

if ! python3 -m pip --version >/dev/null 2>&1; then
    die "python3-pip installation failed"
fi


log "Python:"
log "  $(python3 --version 2>&1)"

log "pip:"
python3 -m pip --version


# ============================================================
# Browser user
# ============================================================

log "checking browser user"

if ! id "$BROWSER_USER" >/dev/null 2>&1; then

    log "creating user: $BROWSER_USER"

    adduser \
        -D \
        -h "$BROWSER_HOME" \
        -s /bin/bash \
        "$BROWSER_USER"

fi


# ============================================================
# Browser directories
# ============================================================

log "creating browser directories"

mkdir -p \
    "$BROWSER_HOME" \
    "$BROWSER_WORK" \
    "$BROWSER_WORK/persistent" \
    "$BROWSER_WORK/profiles" \
    "$BROWSER_WORK/screenshots" \
    "$BROWSER_WORK/task-results" \
    "$BROWSER_WORK/downloaded_files" \
    "$BROWSER_WORK/assets" \
    "$BROWSER_WORK/archived_files"


chown -R \
    "$BROWSER_USER:$BROWSER_USER" \
    "$BROWSER_HOME"


chmod -R a+rX \
    "$BROWSER_WORK" \
    2>/dev/null || true


# ============================================================
# .env.panel
# ============================================================

log "configuring $ENV_FILE"

mkdir -p "$ROOT"

touch "$ENV_FILE"


set_kv() {

    KEY="$1"
    VALUE="$2"

    TMP_FILE="${ENV_FILE}.tmp.$$"

    awk \
        -v key="$KEY" \
        -v value="$VALUE" '

        BEGIN {
            found=0
        }

        $0 ~ ("^" key "=") {

            if (!found) {
                print key "=" value
                found=1
            }

            next
        }

        {
            print
        }

        END {

            if (!found) {
                print key "=" value
            }

        }

    ' "$ENV_FILE" > "$TMP_FILE"

    mv "$TMP_FILE" "$ENV_FILE"

}


# ------------------------------------------------------------
# Core panel settings
# ------------------------------------------------------------

set_kv "PORT" "${PORT:-3210}"

set_kv "HOST" "${HOST:-0.0.0.0}"

set_kv "BROWSER_DISPLAY" "$DISPLAY_NUM"


# ------------------------------------------------------------
# Chromium
# ------------------------------------------------------------

# IMPORTANT:
#
# Use Alpine's launcher:
#
#   /usr/bin/chromium
#
# NOT:
#
#   /usr/lib/chromium/chromium
#
# The launcher prepares Alpine's Chromium environment correctly.

set_kv \
    "BROWSER_CHROME_PATH" \
    "$CHROMIUM_LAUNCHER"


set_kv \
    "PLAYWRIGHT_CHROME_PATH" \
    "$CHROMIUM_LAUNCHER"


# ------------------------------------------------------------
# ChromeDriver
# ------------------------------------------------------------

set_kv \
    "CHROMEDRIVER_PATH" \
    "$CHROMEDRIVER"


set_kv \
    "WEBDRIVER_CHROME_DRIVER" \
    "$CHROMEDRIVER"


# ------------------------------------------------------------
# Browser user
# ------------------------------------------------------------

set_kv \
    "BROWSER_USER" \
    "$BROWSER_USER"


set_kv \
    "BROWSER_HOME" \
    "$BROWSER_HOME"


set_kv \
    "BROWSER_WORK_DIR" \
    "$BROWSER_WORK"


set_kv \
    "BROWSER_XAUTHORITY" \
    "$BROWSER_HOME/.Xauthority"


set_kv \
    "BROWSER_USER_DATA_DIR" \
    "$BROWSER_WORK/persistent"


# ------------------------------------------------------------
# Playwright
# ------------------------------------------------------------

set_kv \
    "PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD" \
    "1"


set_kv \
    "PLAYWRIGHT_BROWSERS_PATH" \
    "0"


chown root:root "$ENV_FILE"

chmod 0644 "$ENV_FILE"


log ".env.panel:"
echo "----------------------------------------"
cat "$ENV_FILE"
echo "----------------------------------------"


# ============================================================
# Python packages
# ============================================================

log "installing Python packages"

PIP_ARGS="
--break-system-packages
--ignore-installed
--disable-pip-version-check
--no-cache-dir
"


python3 -m pip install \
    $PIP_ARGS \
    -U \
    setuptools \
    wheel


# ------------------------------------------------------------
# Optional panel requirements
# ------------------------------------------------------------

REQUIREMENTS=""

for requirement_file in \
    "$ROOT/requirements-dp.txt" \
    "$ROOT/requirements-sb.txt" \
    "$ROOT/requirements-playwright.txt"
do

    if [ -f "$requirement_file" ]; then

        REQUIREMENTS="$REQUIREMENTS -r $requirement_file"

    fi

done


# ------------------------------------------------------------
# Main Python stack
# ------------------------------------------------------------

log "installing browser automation Python stack"


# shellcheck disable=SC2086
python3 -m pip install \
    $PIP_ARGS \
    -U \
    $REQUIREMENTS \
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


# ============================================================
# Python verification
# ============================================================

log "verifying Python imports"

python3 <<'PY'
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
        failed.append(
            f"{name}: {exc}"
        )


if failed:

    print(
        "Python runtime verification failed:",
        file=sys.stderr
    )

    for item in failed:
        print(
            "  - " + item,
            file=sys.stderr
        )

    raise SystemExit(1)


print("Python runtime imports: OK")

PY


# ============================================================
# Playwright configuration
# ============================================================

export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1

export PLAYWRIGHT_BROWSERS_PATH=0


log "Playwright browser download disabled"

log "System Chromium will be used."



echo ""
echo "========================================"
echo "INSTALLATION COMPLETE"
echo "========================================"


log "Browser:"
log "  $CHROMIUM_LAUNCHER"

log "ChromeDriver:"
log "  $CHROMEDRIVER"

log "Environment:"
log "  $ENV_FILE"

log ""
log "Important:"
log "  - Use /usr/bin/chromium for browser-panel."
log "  - Do NOT run: playwright install"
log "  - Xvfb must be started manually in proot mode"
log "  - Use DISPLAY=:1 before starting browser-panel"
log "  - ChromeDriver comes from Alpine chromium-chromedriver."
log "  - Playwright uses system Chromium."
