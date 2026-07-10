#!/bin/sh
# Title: DarkSec-Chat
# Description: Mesh networking + web bridge chat client with LCD UI
# Author: wickednull
# Version: 2.0
# Category: general
# Library: libpagerctl.so (pagerctl)

# Payload metadata for pager theme engine
_PAYLOAD_TITLE="DarkSec-Chat"
_PAYLOAD_AUTHOR_NAME="wickednull"
_PAYLOAD_VERSION="2.0"
_PAYLOAD_DESCRIPTION="Mesh + Web Chat Client for WiFi Pineapple Pager"

PAYLOAD_DIR="/root/payloads/user/general/darksec-chat"
DATA_DIR="$PAYLOAD_DIR/data"

cd "$PAYLOAD_DIR" || {
    LOG "red" "ERROR: $PAYLOAD_DIR not found"
    exit 1
}

#
# Find and setup pagerctl dependencies (libpagerctl.so + pagerctl.py)
# lib/ is the canonical location -- check it first, then payload root, then external PAGERCTL
#
PAGERCTL_FOUND=false
for dir in "$PAYLOAD_DIR/lib" "$PAYLOAD_DIR" "/mmc/root/payloads/user/utilities/PAGERCTL"; do
    if [ -f "$dir/libpagerctl.so" ] && [ -f "$dir/pagerctl.py" ]; then
        PAGERCTL_DIR="$dir"
        PAGERCTL_FOUND=true
        break
    fi
done

if [ "$PAGERCTL_FOUND" = false ]; then
    LOG ""
    LOG "red" "=== MISSING DEPENDENCY ==="
    LOG ""
    LOG "red" "libpagerctl.so and pagerctl.py not found!"
    LOG ""
    LOG "Searched:"
    for dir in "$PAYLOAD_DIR/lib" "$PAYLOAD_DIR" "/mmc/root/payloads/user/utilities/PAGERCTL"; do
        LOG "  $dir"
    done
    LOG ""
    LOG "Install PAGERCTL payload or copy files to:"
    LOG "  $PAYLOAD_DIR/lib/"
    LOG ""
    LOG "Press any button to exit..."
    WAIT_FOR_INPUT >/dev/null 2>&1
    exit 1
fi

# Copy to lib/ if found outside of it (payload root or external PAGERCTL)
if [ "$PAGERCTL_DIR" != "$PAYLOAD_DIR/lib" ]; then
    mkdir -p "$PAYLOAD_DIR/lib" 2>/dev/null
    cp "$PAGERCTL_DIR/libpagerctl.so" "$PAYLOAD_DIR/lib/" 2>/dev/null
    cp "$PAGERCTL_DIR/pagerctl.py" "$PAYLOAD_DIR/lib/" 2>/dev/null
    LOG "green" "Copied pagerctl from $PAGERCTL_DIR to lib/"
fi

#
# Setup local paths for bundled Python modules and native libs
#
export PATH="/mmc/usr/bin:$PATH"
export PYTHONPATH="$PAYLOAD_DIR/lib:$PAYLOAD_DIR:$PYTHONPATH"
export LD_LIBRARY_PATH="/mmc/usr/lib:$PAYLOAD_DIR/lib:$LD_LIBRARY_PATH"

# Source config
if [ -f "$PAYLOAD_DIR/config.sh" ]; then
    . "$PAYLOAD_DIR/config.sh"
    export WEB_API_URL USERNAME UDP_PORT TCP_PORT
fi

#
# Check for Python3 and python3-ctypes - required system dependencies
#
NEED_PYTHON=false
NEED_CTYPES=false

if ! command -v python3 >/dev/null 2>&1; then
    NEED_PYTHON=true
    NEED_CTYPES=true
elif ! python3 -c "import ctypes" 2>/dev/null; then
    NEED_CTYPES=true
fi

if [ "$NEED_PYTHON" = true ] || [ "$NEED_CTYPES" = true ]; then
    LOG ""
    LOG "red" "=== MISSING REQUIREMENT ==="
    LOG ""
    if [ "$NEED_PYTHON" = true ]; then
        LOG "Python3 is required to run DarkSec-Chat."
    else
        LOG "Python3-ctypes is required to run DarkSec-Chat."
    fi
    LOG ""
    LOG "green" "GREEN = Install dependencies (requires internet)"
    LOG "red" "RED   = Exit"
    LOG ""

    while true; do
        BUTTON=$(WAIT_FOR_INPUT 2>/dev/null)
        case "$BUTTON" in
            "GREEN"|"A")
                LOG ""
                LOG "Updating package lists..."
                opkg update 2>&1 | while IFS= read -r line; do LOG "  $line"; done
                LOG ""
                LOG "Installing Python3 + ctypes to MMC..."
                opkg -d mmc install python3 python3-ctypes 2>&1 | while IFS= read -r line; do LOG "  $line"; done
                LOG ""
                if command -v python3 >/dev/null 2>&1 && python3 -c "import ctypes" 2>/dev/null; then
                    LOG "green" "Python3 installed successfully!"
                    sleep 1
                else
                    LOG "red" "Failed to install Python3"
                    LOG "red" "Check internet connection and try again."
                    LOG ""
                    LOG "Press any button to exit..."
                    WAIT_FOR_INPUT >/dev/null 2>&1
                    exit 1
                fi
                break
                ;;
            "RED"|"B")
                LOG "Exiting."
                exit 0
                ;;
        esac
    done
fi

# Check for requests (optional, enables web bridge)
if ! python3 -c "import requests" 2>/dev/null; then
    LOG "yellow" "python3-requests not found (web bridge disabled)"
    LOG "yellow" "Install: opkg -d mmc install python3-requests"
fi

# ============================================================
# CLEANUP
# ============================================================

cleanup() {
    # Restart pager service if not running
    if ! pgrep -x pineapple >/dev/null 2>&1; then
        /etc/init.d/pineapplepager start 2>/dev/null
    fi
}

trap cleanup EXIT

# ============================================================
# MAIN
# ============================================================

LOG ""
LOG "green" "================================"
LOG "green" "       DarkSec-Chat v2"
LOG "green" "  Mesh + Web Chat for Pager"
LOG "green" "================================"
LOG ""
LOG "Launching chat client..."
LOG ""
LOG "green" "  GREEN = Start DarkSec-Chat"
LOG "red" "  RED   = Exit"
LOG ""

while true; do
    BUTTON=$(WAIT_FOR_INPUT 2>/dev/null)
    case "$BUTTON" in
        "GREEN"|"A")
            break
            ;;
        "RED"|"B")
            LOG "Exiting."
            exit 0
            ;;
    esac
done

# Create data directory
mkdir -p "$DATA_DIR" 2>/dev/null

# Stop pager service and take over display
SPINNER_ID=$(START_SPINNER "Starting DarkSec-Chat...")
/etc/init.d/pineapplepager stop 2>/dev/null
sleep 0.5
STOP_SPINNER "$SPINNER_ID" 2>/dev/null

# Payload loop -- supports exit code 42 handoff
NEXT_PAYLOAD_FILE="$DATA_DIR/.next_payload"

while true; do
    cd "$PAYLOAD_DIR"
    python3 darksec_chat.py
    EXIT_CODE=$?

    # Exit code 42 = hand off to another payload
    if [ "$EXIT_CODE" -eq 42 ] && [ -f "$NEXT_PAYLOAD_FILE" ]; then
        NEXT_SCRIPT=$(cat "$NEXT_PAYLOAD_FILE")
        rm -f "$NEXT_PAYLOAD_FILE"
        if [ -f "$NEXT_SCRIPT" ]; then
            sh "$NEXT_SCRIPT"
            [ $? -eq 42 ] && continue
        fi
    fi

    break
done

exit 0
