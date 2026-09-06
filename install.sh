#!/bin/sh

# ============================================================
# Alpine Linux browser-panel dependency installer
# ============================================================

set -eu

ROOT="${PANEL_ROOT:-/opt/browser-panel}"
ENV_FILE="${PANEL_ENV:-$ROOT/.env.panel}"

BROWSER_USER="${BROWSER_USER:-browser}"
BROWSER_HOME="${BROWSER_HOME:-/home/$BROWSER_USER}"
BROWSER_WORK="${BROWSER_WORK_DIR:-$BROWSER_HOME/browser-work}"

DISPLAY_NUM="${BROWSER_DISPLAY:-:1}"

log() {
    echo "[browser-panel] $*"
}

die() {
    echo "[browser-panel] ERROR: $*" >&2
    exit 1
}


# ============================================================
# Root
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
    die "please run as root"
fi


# ============================================================
# Alpine
# ============================================================

if [ ! -f /etc/alpine-release ]; then
    die "this installer is for Alpine Linux"
fi

if ! command -v apk >/dev/null 2>&1; then
    die "apk not found"
fi


ALPINE_VERSION="$(cat /etc/alpine-release)"
BRANCH="$(echo "$ALPINE_VERSION" | cut -d. -f1,2)"

log "Alpine: $ALPINE_VERSION"


# ============================================================
# Repository
# ============================================================

if [ -f /etc/apk/repositories ]; then

    if ! grep -Eq '^[[:space:]]*[^#].*/community/?[[:space:]]*$' \
        /etc/apk/repositories
    then
        echo "https://dl-cdn.alpinelinux.org/alpine/v${BRANCH}/community" \
            >> /etc/apk/repositories
    fi

fi


# ============================================================
# APK
# ============================================================

log "Updating APK indexes"

apk update


# ============================================================
# System dependencies
# ============================================================

log "Installing system dependencies"

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

# Optional font
apk add --no-cache font-opensans 2>/dev/null || true


# ============================================================
# Browser user
# ============================================================

if ! id "$BROWSER_USER" >/dev/null 2>&1; then

    log "Creating user: $BROWSER_USER"

    adduser \
        -D \
        -h "$BROWSER_HOME" \
        -s /bin/bash \
        "$BROWSER_USER"

fi


# ============================================================
# Directories
# ============================================================

log "Creating browser directories"

mkdir -p \
    "$ROOT" \
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
# Chromium paths
# ============================================================

# Alpine normally uses /usr/bin/chromium.
# Keep chromium-browser as fallback.

if [ -x /usr/bin/chromium ]; then
    CHROME_PATH="/usr/bin/chromium"
else
    CHROME_PATH="/usr/bin/chromium-browser"
fi


if [ -x /usr/bin/chromedriver ]; then
    CHROMEDRIVER_PATH="/usr/bin/chromedriver"
else
    CHROMEDRIVER_PATH="/usr/lib/chromium/chromedriver"
fi


# ============================================================
# .env.panel
# ============================================================

log "Writing $ENV_FILE"

mkdir -p "$(dirname "$ENV_FILE")"

touch "$ENV_FILE"


set_kv() {

    KEY="$1"
    VALUE="$2"

    TMP="${ENV_FILE}.tmp.$$"

    if grep -q "^${KEY}=" "$ENV_FILE" 2>/dev/null; then

        sed \
            "s|^${KEY}=.*|${KEY}=${VALUE}|" \
            "$ENV_FILE" > "$TMP"

        mv "$TMP" "$ENV_FILE"

    else

        printf '%s=%s\n' \
            "$KEY" \
            "$VALUE" >> "$ENV_FILE"

    fi
}


set_kv_if_missing() {

    KEY="$1"
    VALUE="$2"

    if ! grep -q "^${KEY}=" "$ENV_FILE" 2>/dev/null; then

        printf '%s=%s\n' \
            "$KEY" \
            "$VALUE" >> "$ENV_FILE"

    fi
}


# ============================================================
# Panel
# ============================================================

set_kv_if_missing PORT "3210"
set_kv_if_missing HOST "0.0.0.0"

set_kv BROWSER_DISPLAY "$DISPLAY_NUM"

set_kv BROWSER_CHROME_PATH "$CHROME_PATH"

set_kv BROWSER_USER "$BROWSER_USER"
set_kv BROWSER_HOME "$BROWSER_HOME"
set_kv BROWSER_WORK_DIR "$BROWSER_WORK"

set_kv BROWSER_XAUTHORITY \
    "$BROWSER_HOME/.Xauthority"

set_kv BROWSER_USER_DATA_DIR \
    "$BROWSER_WORK/persistent"

set_kv_if_missing CHROMEDRIVER_PATH \
    "$CHROMEDRIVER_PATH"


# ============================================================
# Permissions
# ============================================================

chown root:root "$ENV_FILE"
chmod 0644 "$ENV_FILE"


# ============================================================
# Python
# ============================================================

log "Installing Python packages"

python3 -m pip install \
    --break-system-packages \
    --ignore-installed \
    --disable-pip-version-check \
    --no-cache-dir \
    -U \
    setuptools \
    wheel


python3 -m pip install \
    --break-system-packages \
    --ignore-installed \
    --disable-pip-version-check \
    --no-cache-dir \
    -U \
    "requests>=2.31.0" \
    "urllib3>=2.0.0" \
    "Pillow>=10.0.0" \
    "DrissionPage>=4.1.0" \
    "selenium>=4.20.0" \
    "seleniumbase>=4.30.0" \
    "pyrogram>=2.0.0" \
    "TgCrypto>=1.2.0" \
    "SpeechRecognition>=3.10.0" \
    "pydub>=0.25.0" \
    "numpy>=1.24.0"


# ============================================================
# Existing requirements files
# ============================================================

for FILE in \
    "$ROOT/requirements-dp.txt" \
    "$ROOT/requirements-sb.txt" \
    "$ROOT/requirements-playwright.txt"
do

    if [ -f "$FILE" ]; then

        log "Installing $FILE"

        python3 -m pip install \
            --break-system-packages \
            --ignore-installed \
            --disable-pip-version-check \
            --no-cache-dir \
            -r "$FILE"

    fi

done


# ============================================================
# Environment
# ============================================================

export DISPLAY="$DISPLAY_NUM"
export XAUTHORITY="$BROWSER_HOME/.Xauthority"

export PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
export PLAYWRIGHT_BROWSERS_PATH=0


# ============================================================
# Done
# ============================================================

echo
echo "========================================"
echo " Browser Panel Dependencies Installed"
echo "========================================"
echo
echo "Chromium:      $CHROME_PATH"
echo "ChromeDriver:  $CHROMEDRIVER_PATH"
echo "Python:        $(python3 --version 2>&1)"
echo "Node:          $(node -v)"
echo "npm:           $(npm -v)"
echo "Display:       $DISPLAY_NUM"
echo "Browser user:  $BROWSER_USER"
echo "Work dir:      $BROWSER_WORK"
echo "Env:           $ENV_FILE"
echo
echo "Playwright browser download: DISABLED"
echo
