#!/bin/sh

# ============================================================
# Alpine Linux browser-panel dependency installer
# ============================================================
#
# Designed for:
#   Alpine Linux 3.20+
#   Alpine Linux 3.21+
#   Alpine Linux 3.22+
#
# Installs:
#   - Chromium
#   - Chromium ChromeDriver
#   - Xvfb
#   - xauth
#   - xdotool
#   - scrot
#   - ffmpeg
#   - Noto fonts / CJK / Emoji
#   - Python 3 + pip
#   - Python build toolchain
#   - Node.js + npm
#   - DrissionPage
#   - Selenium
#   - SeleniumBase
#   - Pyrogram
#   - TgCrypto
#   - SpeechRecognition
#   - pydub
#   - numpy
#   - Pillow
#
# IMPORTANT:
#   Playwright is NOT installed.
#
#   Playwright Python/browser support on Alpine/musl is problematic.
#   This installer uses the system Chromium + ChromeDriver instead.
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
    echo "[browser-panel] $*"
}

die() {
    echo "[browser-panel] ERROR: $*" >&2
    exit 1
}


# ============================================================
# Root check
# ============================================================

if [ "$(id -u)" -ne 0 ]; then
    die "please run this installer as root"
fi


# ============================================================
# Alpine check
# ============================================================

if [ ! -f /etc/alpine-release ]; then
    die "this installer is for Alpine Linux only"
fi

if ! command -v apk >/dev/null 2>&1; then
    die "apk command not found"
fi


ALPINE_VERSION="$(cat /etc/alpine-release)"

ALPINE_BRANCH="$(echo "$ALPINE_VERSION" | cut -d. -f1,2)"

ARCH="$(uname -m)"


log "========================================"
log "Alpine browser-panel installer"
log "========================================"
log "Alpine:       $ALPINE_VERSION"
log "Architecture: $ARCH"
log "Panel root:   $ROOT"
log "Browser user: $BROWSER_USER"
log "Display:      $DISPLAY_NUM"
log "========================================"


# ============================================================
# Alpine repositories
# ============================================================

log "Configuring Alpine repositories"

if [ -f /etc/apk/repositories ]; then

    if ! grep -Eq '^[[:space:]]*[^#].*/community/?[[:space:]]*$' \
        /etc/apk/repositories
    then

        echo \
            "https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_BRANCH}/community" \
            >> /etc/apk/repositories

        log "Added community repository"

    fi

fi


# ============================================================
# APK update
# ============================================================

log "Updating APK indexes"

apk update


# ============================================================
# System packages
# ============================================================

log "Installing system packages"

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


# ============================================================
# Optional font
# ============================================================

apk add --no-cache \
    font-opensans \
    2>/dev/null || true


# Refresh font cache if available.

if command -v fc-cache >/dev/null 2>&1; then
    fc-cache -f >/dev/null 2>&1 || true
fi


# ============================================================
# Chromium path
# ============================================================

# Alpine normally provides:
#
#   /usr/bin/chromium
#
# Some older/custom environments may provide:
#
#   /usr/bin/chromium-browser
#
# Do NOT abort installation if the path is unusual.
# Just select the common path for the environment file.

if [ -x /usr/bin/chromium ]; then

    CHROME_PATH="/usr/bin/chromium"

elif [ -x /usr/bin/chromium-browser ]; then

    CHROME_PATH="/usr/bin/chromium-browser"

else

    CHROME_PATH="/usr/bin/chromium"

fi


# ============================================================
# ChromeDriver path
# ============================================================

if [ -x /usr/bin/chromedriver ]; then

    CHROMEDRIVER_PATH="/usr/bin/chromedriver"

elif [ -x /usr/lib/chromium/chromedriver ]; then

    CHROMEDRIVER_PATH="/usr/lib/chromium/chromedriver"

else

    CHROMEDRIVER_PATH="/usr/bin/chromedriver"

fi


log "Chromium path:     $CHROME_PATH"

log "ChromeDriver path: $CHROMEDRIVER_PATH"


# ============================================================
# Browser user
# ============================================================

log "Configuring browser user"

if ! id "$BROWSER_USER" >/dev/null 2>&1; then

    log "Creating user: $BROWSER_USER"

    adduser \
        -D \
        -h "$BROWSER_HOME" \
        -s /bin/bash \
        "$BROWSER_USER"

fi


# ============================================================
# Browser directories
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


# ============================================================
# Permissions
# ============================================================

chown -R \
    "$BROWSER_USER:$BROWSER_USER" \
    "$BROWSER_HOME"


chmod -R a+rX \
    "$BROWSER_WORK" \
    2>/dev/null || true


# ============================================================
# Environment file
# ============================================================

log "Configuring environment: $ENV_FILE"

mkdir -p "$(dirname "$ENV_FILE")"

touch "$ENV_FILE"


# ============================================================
# set_kv
# ============================================================

set_kv() {

    KEY="$1"

    VALUE="$2"

    TMP_FILE="${ENV_FILE}.tmp.$$"


    if grep -q "^${KEY}=" "$ENV_FILE" 2>/dev/null; then

        sed \
            "s|^${KEY}=.*|${KEY}=${VALUE}|" \
            "$ENV_FILE" \
            > "$TMP_FILE"

        mv "$TMP_FILE" "$ENV_FILE"

    else

        printf '%s=%s\n' \
            "$KEY" \
            "$VALUE" \
            >> "$ENV_FILE"

    fi
}


# ============================================================
# set_kv_if_missing
# ============================================================

set_kv_if_missing() {

    KEY="$1"

    VALUE="$2"


    if ! grep -q "^${KEY}=" "$ENV_FILE" 2>/dev/null; then

        printf '%s=%s\n' \
            "$KEY" \
            "$VALUE" \
            >> "$ENV_FILE"

    fi
}


# ============================================================
# Panel configuration
# ============================================================

set_kv_if_missing \
    PORT \
    "3210"


set_kv_if_missing \
    HOST \
    "0.0.0.0"


set_kv \
    BROWSER_DISPLAY \
    "$DISPLAY_NUM"


# ============================================================
# Chromium
# ============================================================

set_kv \
    BROWSER_CHROME_PATH \
    "$CHROME_PATH"


set_kv \
    CHROME_PATH \
    "$CHROME_PATH"


# ============================================================
# ChromeDriver
# ============================================================

set_kv \
    CHROMEDRIVER_PATH \
    "$CHROMEDRIVER_PATH"


set_kv \
    WEBDRIVER_CHROME_DRIVER \
    "$CHROMEDRIVER_PATH"


# ============================================================
# Browser user
# ============================================================

set_kv \
    BROWSER_USER \
    "$BROWSER_USER"


set_kv \
    BROWSER_HOME \
    "$BROWSER_HOME"


set_kv \
    BROWSER_WORK_DIR \
    "$BROWSER_WORK"


set_kv \
    BROWSER_XAUTHORITY \
    "$BROWSER_HOME/.Xauthority"


set_kv \
    BROWSER_USER_DATA_DIR \
    "$BROWSER_WORK/persistent"


# ============================================================
# Environment permissions
# ============================================================

chown root:root "$ENV_FILE"

chmod 0644 "$ENV_FILE"


# ============================================================
# Python
# ============================================================

log "Installing Python packages"


PYTHON_PIP="python3 -m pip"


PIP_OPTIONS="
--break-system-packages
--ignore-installed
--disable-pip-version-check
--no-cache-dir
"


# ============================================================
# Python build helpers
# ============================================================

log "Installing Python build helpers"


# shellcheck disable=SC2086

$PYTHON_PIP install \
    $PIP_OPTIONS \
    -U \
    setuptools \
    wheel


# ============================================================
# Existing requirements files
# ============================================================

REQUIREMENTS=""

for REQUIREMENT_FILE in \
    "$ROOT/requirements-dp.txt" \
    "$ROOT/requirements-sb.txt" \
do

    if [ -f "$REQUIREMENT_FILE" ]; then

        REQUIREMENTS="$REQUIREMENTS -r $REQUIREMENT_FILE"

    fi

done


# ============================================================
# Main Python packages
# ============================================================

log "Installing browser automation Python stack"


# shellcheck disable=SC2086

$PYTHON_PIP install \
    $PIP_OPTIONS \
    -U \
    $REQUIREMENTS \
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
# NOTE ABOUT PLAYWRIGHT
# ============================================================
#
# Playwright is intentionally NOT installed here.
#
# Alpine Linux uses musl instead of glibc.
#
# The browser-panel stack uses:
#
#   Chromium
#   ChromeDriver
#   Selenium
#   SeleniumBase
#   DrissionPage
#
# instead.
#
# ============================================================


# ============================================================
# XAUTHORITY
# ============================================================

XAUTH_FILE="$BROWSER_HOME/.Xauthority"


if [ ! -e "$XAUTH_FILE" ]; then

    touch "$XAUTH_FILE"

fi


chown \
    "$BROWSER_USER:$BROWSER_USER" \
    "$XAUTH_FILE"


# ============================================================
# Environment export
# ============================================================

export DISPLAY="$DISPLAY_NUM"

export XAUTHORITY="$XAUTH_FILE"


# ============================================================
# Final environment
# ============================================================

echo
echo "========================================"
echo " Browser Panel Dependencies Installed"
echo "========================================"
echo
echo "Alpine:          $ALPINE_VERSION"
echo "Architecture:    $ARCH"
echo
echo "Chromium:"
echo "  $CHROME_PATH"
echo
echo "ChromeDriver:"
echo "  $CHROMEDRIVER_PATH"
echo
echo "Python:"
echo "  $(python3 --version 2>&1)"
echo
echo "Node:"
echo "  $(node -v 2>/dev/null || echo unknown)"
echo
echo "npm:"
echo "  $(npm -v 2>/dev/null || echo unknown)"
echo
echo "Display:"
echo "  $DISPLAY_NUM"
echo
echo "Browser user:"
echo "  $BROWSER_USER"
echo
echo "Browser home:"
echo "  $BROWSER_HOME"
echo
echo "Browser work:"
echo "  $BROWSER_WORK"
echo
echo "Environment:"
echo "  $ENV_FILE"
echo
echo "========================================"
echo
echo "Installed:"
echo "  Chromium"
echo "  Chromium ChromeDriver"
echo "  Xvfb"
echo "  Xauth"
echo "  xdotool"
echo "  scrot"
echo "  ffmpeg"
echo "  Noto fonts"
echo "  Python 3"
echo "  Node.js"
echo "  Selenium"
echo "  SeleniumBase"
echo "  DrissionPage"
echo
echo "Playwright:"
echo "  NOT INSTALLED (Alpine/musl)"
echo
echo "========================================"
echo " Installation finished"
echo "========================================"
echo
