#!/usr/bin/env bash
set -euo pipefail
trap 'cleanup $?' EXIT

# ---------------------------
# CONFIGURATION
# ---------------------------
USERNAME="sadat"
DOTFILES_REPO="https://github.com/mylinuxforwork/hyprland-starter.git"
NIXPKGS_COMMIT="9c09d5e27cd07348e2177fcca51badb0446f1a43"
LOG_FILE="/tmp/hyprland-install-$(date +%Y%m%d%H%M%S).log"
STOW_DIR="$HOME/.dotfiles"
PACKAGES=(
    "hyprland"
    "wezterm"
    "waybar"
    "wofi"
    "swaylock"
    "swayidle"
    "wl-clipboard"
    "xdg-desktop-portal-hyprland"
    "grim"
    "slurp"
    "zsh"
    "starship"
    "neovim"
    "git"
    "tmux"
    "fzf"
    "ripgrep"
    "fd"
    "zoxide"
    "bat"
    "eza"
)

# ---------------------------
# FUNCTIONS
# ---------------------------
cleanup() {
    if [[ $1 -ne 0 ]]; then
        echo -e "\n\033[1;31mInstallation failed! See logs: $LOG_FILE\033[0m"
    else
        rm -f "$LOG_FILE"
    fi
}

log() {
    echo -e "\n\033[1;34m$1\033[0m" | tee -a "$LOG_FILE"
}

error() {
    echo -e "\n\033[1;31mError: $1\033[0m" | tee -a "$LOG_FILE" >&2
    exit 1
}

install_nix() {
    log "[1/9] Installing Nix package manager..."
    if ! command -v nix >/dev/null; then
        sh <(curl -L https://nixos.org/nix/install) --daemon --no-channel-add 2>&1 | tee -a "$LOG_FILE" || 
            error "Nix installation failed"
        source /etc/profile.d/nix.sh || error "Nix environment sourcing failed"
    fi
}

configure_nix() {
    log "[2/9] Configuring Nix environment..."
    sudo mkdir -p /etc/nix
    echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
    sudo systemctl restart nix-daemon.service
}

pin_nixpkgs() {
    log "[3/9] Pinning nixpkgs to commit $NIXPKGS_COMMIT..."
    nix registry add nixpkgs "github:NixOS/nixpkgs/$NIXPKGS_COMMIT" 2>&1 | tee -a "$LOG_FILE"
}

install_packages() {
    log "[4/9] Installing Hyprland and dependencies..."
    for pkg in "${PACKAGES[@]}"; do
        nix profile install "nixpkgs#$pkg" 2>&1 | tee -a "$LOG_FILE" || 
            error "Failed to install $pkg"
    done
}

setup_sddm() {
    log "[5/9] Configuring SDDM login manager..."
    sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null <<EOF
[Autologin]
User=$USERNAME
Session=hyprland.desktop

[General]
DisplayServer=wayland
EOF

    sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Wayland compositor
Exec=Hyprland
Type=Application
EOF

    sudo systemctl enable sddm.service 2>&1 | tee -a "$LOG_FILE"
}

setup_dotfiles() {
    log "[6/9] Setting up dotfiles with stow..."
    if [[ ! -d "$STOW_DIR" ]]; then
        git clone "$DOTFILES_REPO" "$STOW_DIR" 2>&1 | tee -a "$LOG_FILE" || 
            error "Dotfiles clone failed"
    fi
    
    # Create basic dotfiles if repo is empty
    mkdir -p "$STOW_DIR"/{hypr,wezterm,zsh}
    tee "$STOW_DIR/hypr/hyprland.conf" >/dev/null <<EOF
exec-once = waybar
exec-once = swayidle
exec-once = dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY

monitor = ,preferred,auto,1

bind = SUPER, Return, exec, wezterm
bind = SUPER, Q, killactive
bind = SUPER, M, exit
EOF

    tee "$STOW_DIR/wezterm/wezterm.lua" >/dev/null <<EOF
return {
    font = wezterm.font('Fira Code'),
    font_size = 12,
    color_scheme = 'Catppuccin Mocha',
    enable_tab_bar = false,
}
EOF

    tee "$STOW_DIR/zsh/.zshrc" >/dev/null <<EOF
export PATH="\$HOME/.nix-profile/bin:\$PATH"
export EDITOR=nvim

# Oh My Zsh
export ZSH="\$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "\$ZSH/oh-my-zsh.sh"

# Starship prompt
eval "\$(starship init zsh)"
EOF

    # Stow dotfiles
    (
        cd "$STOW_DIR" && 
        stow -v hypr wezterm zsh 2>&1 | tee -a "$LOG_FILE"
    )
}

configure_zsh() {
    log "[7/9] Configuring Zsh environment..."
    ZSH_PATH="$(nix eval nixpkgs#zsh.outPath --raw)/bin/zsh"
    if ! grep -q "$ZSH_PATH" /etc/shells; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi
    sudo chsh -s "$ZSH_PATH" "$USER" 2>&1 | tee -a "$LOG_FILE"

    # Install Oh My Zsh
    export ZSH="$HOME/.oh-my-zsh"
    if [[ ! -d "$ZSH" ]]; then
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi

    # Install plugins
    ZSH_CUSTOM="${ZSH}/custom/plugins"
    mkdir -p "$ZSH_CUSTOM"
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/zsh-autosuggestions"
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/zsh-syntax-highlighting"
}

install_developer_tools() {
    log "[8/9] Installing developer tools..."
    nix profile install \
        "nixpkgs#clang-tools" \
        "nixpkgs#nodejs" \
        "nixpkgs#rustup" \
        "nixpkgs#python3" 2>&1 | tee -a "$LOG_FILE"
}

finalize() {
    log "[9/9] Finalizing installation..."
    sudo systemctl restart sddm.service
    log "✅ Installation completed successfully!"
    echo -e "\nNext steps:"
    echo "1. Reboot your system: sudo reboot"
    echo "2. Hyprland will start automatically via SDDM"
    echo "3. Customize dotfiles in: $STOW_DIR"
    echo -e "\nDebug logs: $LOG_FILE"
}

# ---------------------------
# MAIN EXECUTION
# ---------------------------
{
    install_nix
    configure_nix
    pin_nixpkgs
    install_packages
    setup_sddm
    setup_dotfiles
    configure_zsh
    install_developer_tools
    finalize
} | tee -a "$LOG_FILE"