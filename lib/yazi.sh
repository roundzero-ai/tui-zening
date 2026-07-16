# shellcheck shell=bash
# lib/yazi.sh — yazi file manager + lazygit integration, opt-in via --yazi
# (sourced by setup.sh)

setup_yazi() {
    [[ "$INSTALL_YAZI" == true ]] || return 0

    if command -v yazi &>/dev/null; then
        info "yazi — already installed."
    elif [[ "$DRY_RUN" == true ]]; then
        would "install yazi"
    else
        info "Installing yazi..."
        if [[ "$OS" == "Darwin" ]]; then
            brew install yazi
        else
            local yazi_arch yazi_tmp
            case "$ARCH" in
                aarch64|arm64) yazi_arch="aarch64-unknown-linux-musl" ;;
                x86_64)        yazi_arch="x86_64-unknown-linux-musl" ;;
                *) die "Unsupported arch for yazi binary: $ARCH. See https://github.com/sxyazi/yazi" ;;
            esac
            yazi_tmp="$(mktemp -d)"
            if command -v unzip &>/dev/null; then
                info "Downloading yazi (zip)..."
                curl -fL "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${yazi_arch}.zip" \
                    -o "$yazi_tmp/yazi.zip"
                unzip -q "$yazi_tmp/yazi.zip" -d "$yazi_tmp"
            else
                # Pi 4 without unzip: try tar.gz variant
                info "Downloading yazi (tar.gz — unzip not available)..."
                curl -fL "https://github.com/sxyazi/yazi/releases/latest/download/yazi-${yazi_arch}.tar.gz" \
                    -o "$yazi_tmp/yazi.tar.gz"
                tar -xzf "$yazi_tmp/yazi.tar.gz" -C "$yazi_tmp"
            fi
            mkdir -p "$HOME/.local/bin"
            cp "$yazi_tmp/yazi-${yazi_arch}/yazi" "$HOME/.local/bin/yazi"
            chmod +x "$HOME/.local/bin/yazi"
            rm -rf "$yazi_tmp"
            success "yazi installed → ~/.local/bin/yazi"
        fi
    fi

    # lazygit for in-Yazi Git UI
    if command -v lazygit &>/dev/null; then
        info "lazygit — already installed."
    elif [[ "$DRY_RUN" == true ]]; then
        would "install lazygit"
    else
        info "Installing lazygit..."
        if [[ "$OS" == "Darwin" ]]; then
            brew install lazygit
        else
            if $PM_INSTALL lazygit 2>/dev/null && command -v lazygit &>/dev/null; then
                success "lazygit installed via package manager."
            else
                local lg_arch lg_tmp lg_version
                case "$ARCH" in
                    aarch64|arm64) lg_arch="arm64" ;;
                    x86_64)        lg_arch="x86_64" ;;
                    *) die "Unsupported arch for lazygit binary: $ARCH. See https://github.com/jesseduffield/lazygit" ;;
                esac

                lg_tmp="$(mktemp -d)"
                curl -fsSL "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" -o "$lg_tmp/releases.json"
                lg_version="$(grep -m1 '"tag_name":' "$lg_tmp/releases.json" | cut -d '"' -f4)"
                [[ -n "$lg_version" ]] || die "Unable to resolve latest lazygit version from GitHub API."

                curl -fL "https://github.com/jesseduffield/lazygit/releases/download/${lg_version}/lazygit_${lg_version#v}_Linux_${lg_arch}.tar.gz" \
                    -o "$lg_tmp/lazygit.tar.gz"
                tar -xzf "$lg_tmp/lazygit.tar.gz" -C "$lg_tmp" lazygit
                mkdir -p "$HOME/.local/bin"
                cp "$lg_tmp/lazygit" "$HOME/.local/bin/lazygit"
                chmod +x "$HOME/.local/bin/lazygit"
                rm -rf "$lg_tmp"
                success "lazygit installed → ~/.local/bin/lazygit"
            fi
        fi
    fi

    # Deploy yazi config files
    local yazi_conf_dir="$HOME/.config/yazi" f
    for f in yazi.toml keymap.toml theme.toml; do
        deploy_file "$SCRIPT_DIR/config/yazi/$f" "$yazi_conf_dir/$f" "yazi $f"
    done
}
