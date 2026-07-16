# shellcheck shell=bash
# lib/detect.sh — OS/arch/shell detection, package-manager plumbing (sourced by setup.sh)

detect_platform() {
    OS="$(uname)"
    ARCH="$(uname -m)"
    [[ "$OS" == "Darwin" || "$OS" == "Linux" ]] || die "Unsupported OS: $OS"

    CURRENT_SHELL="$(basename "${SHELL:-bash}")"
    if [[ "$CURRENT_SHELL" == "zsh" ]]; then
        RC_FILE="$HOME/.zshrc"
    else
        RC_FILE="$HOME/.bashrc"
        CURRENT_SHELL="bash"
    fi

    info "Detected: $OS / $ARCH / $CURRENT_SHELL → patching $RC_FILE"
}

_is_raspi4() {
    if [[ "$OS" == "Linux" ]] && [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
        if grep -qi "raspberry pi" /proc/device-tree/model 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

setup_package_manager() {
    [[ "$OS" == "Linux" ]] || return 0

    if [[ "$EUID" -eq 0 ]]; then
        SUDO=""
    else
        command -v sudo &>/dev/null || die "sudo is required on Linux when not running as root."
        SUDO="sudo"
        if [[ "$DRY_RUN" == false ]]; then
            if [[ ! -t 0 ]] && ! _is_raspi4; then
                die "This setup needs sudo but no interactive TTY is available. Re-run in a terminal or run as root."
            fi
            # Only pre-cache sudo credentials when a TTY is available (interactive sessions).
            # On Pi 4 (headless), skip pre-caching; PM_INSTALL calls sudo on-demand per-package.
            if [[ -t 0 ]]; then
                info "Requesting sudo access..."
                $SUDO -v
            fi
        fi
    fi

    export DEBIAN_FRONTEND=noninteractive

    if command -v apt-get &>/dev/null; then
        PM_INSTALL="$SUDO apt-get install -y"
        PM_UPDATE="$SUDO apt-get update -o Acquire::Retries=3 -o Acquire::http::Timeout=15 -o Acquire::https::Timeout=15 -o Acquire::ForceIPv4=true"
    elif command -v dnf &>/dev/null; then
        PM_INSTALL="$SUDO dnf install -y"
        PM_UPDATE="$SUDO dnf makecache -y"
    elif command -v pacman &>/dev/null; then
        PM_INSTALL="$SUDO pacman -S --noconfirm"
        PM_UPDATE="$SUDO pacman -Sy"
    else
        die "No supported package manager found (apt, dnf, pacman)."
    fi

    PM_UPDATED=false
}

run_pm_update_once() {
    if [[ "$PM_UPDATED" == true ]]; then
        return 0
    fi
    info "Updating package index..."
    PM_UPDATED=true
    if command -v timeout &>/dev/null; then
        if ! timeout 300s bash -lc "$PM_UPDATE"; then
            warn "Package index update timed out/failed after 5 minutes; continuing with existing package metadata."
            return 1
        fi
    else
        if ! eval "$PM_UPDATE"; then
            warn "Package index update failed; continuing with existing package metadata."
            return 1
        fi
    fi
    return 0
}

# Install a package if its command is missing (dry-run aware).
install_pkg() {
    local cmd="$1" pkg="${2:-$1}"
    if ! command -v "$cmd" &>/dev/null; then
        if [[ "$DRY_RUN" == true ]]; then
            would "install $pkg"
            return 0
        fi
        info "Installing $pkg..."
        if [[ "$OS" == "Darwin" ]]; then
            brew install "$pkg"
        else
            if ! $PM_INSTALL "$pkg"; then
                run_pm_update_once || true
                $PM_INSTALL "$pkg"
            fi
        fi
    else
        info "$cmd — already installed."
    fi
}
