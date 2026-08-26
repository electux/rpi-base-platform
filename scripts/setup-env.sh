#!/usr/bin/env bash
# Yocto Environment Initialization Wrapper Script
# Must be sourced from a bash-compatible shell.

if [ "$0" = "${BASH_SOURCE[0]}" ]; then
    echo "Error: This script must be sourced, not executed directly."
    echo "Usage: source scripts/setup-env.sh [build-dir]"
    exit 1 2>/dev/null || return 1
fi

# Detect SCRIPT_PATH and BASE_DIR dynamically
if [ -n "$BASH_SOURCE" ]; then
    SCRIPT_PATH="${BASH_SOURCE[0]}"
elif [ -n "$ZSH_NAME" ]; then
    SCRIPT_PATH="$0"
else
    # Fallback to local directory
    SCRIPT_PATH="./scripts/setup-env.sh"
fi

# Resolve absolute paths
SCRIPT_DIR=$(dirname "$(readlink -f "$SCRIPT_PATH" 2>/dev/null || perl -MCwd -e 'print Cwd::abs_path shift' "$SCRIPT_PATH")")
BASE_DIR=$(dirname "$SCRIPT_DIR")

# 1. Verify Git submodules are initialized
if [ ! -f "$BASE_DIR/layers/poky/oe-init-build-env" ]; then
    echo "[*] Yocto layers not found. Attempting to initialize Git submodules..."
    (cd "$BASE_DIR" && git submodule update --init --recursive)
    
    if [ ! -f "$BASE_DIR/layers/poky/oe-init-build-env" ]; then
        echo "[!] Error: Failed to initialize Git submodules. Please check your internet connection and run:"
        echo "    git submodule update --init --recursive"
        return 1
    fi
fi

# 2. Export local config directory as template for Yocto
export TEMPLATECONF="$BASE_DIR/configs/meta-rpi-base/conf/templates/default"

# 3. Setup build directory path (relative to BASE_DIR if not absolute)
BUILD_DIR="${1:-build-rpi3-64}"
if [[ "$BUILD_DIR" != /* ]]; then
    BUILD_DIR="$BASE_DIR/$BUILD_DIR"
fi

echo "[-] Sourcing Yocto build environment..."
echo "    Build Directory: $BUILD_DIR"
echo "    Template Conf  : $TEMPLATECONF"

source "$BASE_DIR/layers/poky/oe-init-build-env" "$BUILD_DIR"
