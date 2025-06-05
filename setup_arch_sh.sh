#!/usr/bin/env bash
set -euo pipefail

# ✅ Configuration
USERNAME="sadat"
NIXPKGS_COMMIT="9c09d5e27cd07348e2177fcca51badb0446f1a43"
NIXPKGS="github:NixOS/nixpkgs/${NIXPKGS_COMMIT}"
DOTFILES_REPO="https://github.com/yourusername/dotfiles.git"  # Change to your dotfiles

# ✅ Ensure script is run as normal user
if [[ $EUID -eq 0 ]]; then
    echo "❌ Do not run as root! Run as normal user with sudo privileges."
    exit 1
fi

# ✅ Install Nix if not already installed
echo "[1/10] 🛠️ Installing Nix (multi-user mode)..."
if ! command -v nix >/dev/null; then
    # Pre-install checks
    if ! grep -q "nixbld" /etc/group; then
        sudo groupadd --system nixbld
    fi
    
    # Secure install with checksums
    curl -L https://releases.nixos.org/nix/nix-2.20.3/install | \
        sh -s -- --daemon --no-channel-add
    
    # Verify installation
    if ! command -v nix; then
        echo "❌ Nix installation failed!"
        exit 1
    fi
fi

# ✅ Source nix environment
echo "[2/10] 🔌 Sourcing nix environment..."
source /etc/profile.d/nix.sh >/dev/null 2>&1 || \
    source "${HOME}/.nix-profile/etc/profile.d/nix.sh"

# ✅ Configure Nix
echo "[3/10] ⚙️ Configuring Nix..."
sudo mkdir -p /etc/nix
echo "experimental-features = nix-command flakes" | sudo tee -a /etc/nix/nix.conf >/dev/null
echo "trusted-users = ${USER} root" | sudo tee -a /etc/nix/nix.conf >/dev/null
sudo systemctl restart nix-daemon.service

# ✅ Pin nixpkgs registry
echo "[4/10] 📌 Pinning nixpkgs to commit ${NIXPKGS_COMMIT}..."
nix registry pin nixpkgs "$NIXPKGS"
nix-channel --remove nixpkgs  # Remove default channel

# ✅ Install desktop environment
echo "[5/10] 🖼 Installing desktop environment with Nix..."
nix profile install \
    "nixpkgs#hyprland" \
    "nixpkgs#waybar" \
    "nixpkgs#wofi" \
    "nixpkgs#swaylock" \
    "nixpkgs#swayidle" \
    "nixpkgs#wl-clipboard" \
    "nixpkgs#xdg-desktop-portal-hyprland" \
    "nixpkgs#qt5.qtwayland" \
    "nixpkgs#qt6.qtwayland" \
    "nixpkgs#grim" \
    "nixpkgs#slurp" \
    "nixpkgs#wezterm" \
    "nixpkgs#sddm" \          # Install SDDM via Nix
    "nixpkgs#sddm-kcm" \      # KCM module via Nix
    "nixpkgs#zsh" \
    "nixpkgs#starship"

# ✅ Install development tools
echo "[6/10] 💻 Installing development tools..."
nix profile install \
    "nixpkgs#neovim" \
    "nixpkgs#git" \
    "nixpkgs#python3" \
    "nixpkgs#nodejs" \
    "nixpkgs#tmux" \
    "nixpkgs#clang-tools" \
    "nixpkgs#ripgrep" \
    "nixpkgs#fd" \
    "nixpkgs#fzf" \
    "nixpkgs#zoxide" \
    "nixpkgs#bat" \
    "nixpkgs#eza"

# ✅ Configure SDDM
echo "[7/10] 🔐 Configuring SDDM login manager..."
# Create systemd service for Nix-managed SDDM
sudo tee /etc/systemd/system/sddm.service >/dev/null <<EOF
[Unit]
Description=Simple Desktop Display Manager
Documentation=man:sddm(1) man:sddm.conf(5)
Conflicts=getty@tty1.service
After=systemd-user-sessions.service getty@tty1.service plymouth-quit.service

[Service]
ExecStart=/nix/var/nix/profiles/default/bin/sddm
Restart=always

[Install]
Alias=display-manager.service
WantedBy=graphical.target
EOF

# Configure autologin
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/autologin.conf >/dev/null <<EOF
[Autologin]
User=${USERNAME}
Session=hyprland.desktop

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell

[Theme]
Current=breeze
EOF

# Create Hyprland desktop entry
sudo mkdir -p /usr/share/wayland-sessions
sudo tee /usr/share/wayland-sessions/hyprland.desktop >/dev/null <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Wayland compositor
Exec=Hyprland
Type=Application
EOF

# ✅ Configure shell environment
echo "[8/10] 🐚 Configuring Zsh environment..."
# Set Zsh as default shell
NIX_ZSH_PATH="$(nix eval nixpkgs#zsh.outPath --raw)/bin/zsh"
if ! grep -q "$NIX_ZSH_PATH" /etc/shells; then
    echo "$NIX_ZSH_PATH" | sudo tee -a /etc/shells
fi
sudo chsh -s "$NIX_ZSH_PATH" "$USER"

# Install Oh My Zsh
export ZSH="${HOME}/.oh-my-zsh"
if [[ ! -d "$ZSH" ]]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
fi

# Install Zsh plugins
ZSH_CUSTOM="${ZSH}/custom"
mkdir -p "${ZSH_CUSTOM}/plugins"
git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM}/plugins/zsh-autosuggestions"
git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM}/plugins/zsh-syntax-highlighting"

# Create minimal .zshrc
cat > "${HOME}/.zshrc" <<EOF
export PATH="\$HOME/.nix-profile/bin:/nix/var/nix/profiles/default/bin:\$PATH"
export EDITOR=nvim

# Nix
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
fi

# Oh My Zsh
export ZSH="${ZSH}"
export ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source "\${ZSH}/oh-my-zsh.sh"

# Starship prompt
eval "\$(starship init zsh)"
EOF

# ✅ Install dotfiles
echo "[9/10] ⚙️ Installing dotfiles..."
if [[ -n "$DOTFILES_REPO" ]]; then
    DOTFILES_DIR="${HOME}/.dotfiles"
    if [[ ! -d "$DOTFILES_DIR" ]]; then
        git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
    fi
    
    # Symlink dotfiles
    mkdir -p "${HOME}/.config"
    ln -sf "${DOTFILES_DIR}/hypr" "${HOME}/.config/hypr"
    ln -sf "${DOTFILES_DIR}/wezterm" "${HOME}/.config/wezterm"
    ln -sf "${DOTFILES_DIR}/nvim" "${HOME}/.config/nvim"
else
    echo "⚠️ No DOTFILES_REPO set, skipping dotfiles installation"
fi

# ✅ Create auto-start script
echo "[10/10] 🚀 Creating autostart configuration..."
mkdir -p "${HOME}/.config/hypr"
cat > "${HOME}/.config/hypr/hyprland.conf" <<EOF
exec-once = dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY
exec-once = systemctl --user import-environment DISPLAY WAYLAND_DISPLAY
exec-once = wezterm start --always-new-process
exec-once = waybar
exec-once = swayidle -w timeout 300 'swaylock -f' timeout 600 'hyprctl dispatch dpms off' resume 'hyprctl dispatch dpms on'

bind = SUPER, Return, exec, wezterm
bind = SUPER, Q, killactive,
bind = SUPER, M, exit,

monitor = ,preferred,auto,1
EOF

# ✅ Enable services
echo "[11/11] 🚀 Enabling services..."
sudo systemctl enable sddm.service

# ✅ Final setup
echo
echo "✅ Installation complete!"
echo
echo "🔐 SDDM login manager configured for autologin with user: $USERNAME"
echo "🖥️ Hyprland will start automatically after login"
echo
echo "👉 Next steps:"
echo "1. Reboot your system:"
echo "   sudo reboot"
echo "2. System will automatically:"
echo "   - Start SDDM"
echo "   - Auto-login to your account"
echo "   - Launch Hyprland"
echo
echo "💡 To manage packages:"
echo "   nix profile list             # List installed"
echo "   nix profile install nixpkgs#<package>  # Add new"
echo "   nix profile upgrade --all    # Update packages"
echo "   nix profile remove <number>  # Remove package"
echo
echo "🔒 Pinned nixpkgs: ${NIXPKGS_COMMIT}"