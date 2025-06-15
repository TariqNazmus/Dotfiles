#!/bin/bash

# Exit on error, unset variables, or pipeline failure
set -euo pipefail

# Constants
MAIN_USER="sadat"
STATE_DIR="/tmp/arch_setup_state_nix"
NIX_LOG="$STATE_DIR/nix_errors.log"
USER_HOME=""
ZSH_URL="http://www.zsh.org/pub/zsh-5.9.tar.xz"
NIX_CONFIG_DIR="/home/$MAIN_USER/.config/nixpkgs"
ZSH_PATH="/nix/var/nix/profiles/default/bin/zsh"
NIX_VERSION="2.24.9"
NIX_INSTALLER_URL="https://releases.nixos.org/nix/nix-$NIX_VERSION/nix-$NIX_VERSION-x86_64-linux.tar.xz"
NIX_INSTALLER_SHA256="3c0779e4878d1289cf3fbb158ec5ea9bdf61dfb9b4efac6b3b0b6bec5ba4cf13"
NIXPKGS_COMMIT="5f4f306bea96741f1588ea4f450b2a2e29f42b98"
OHMYZSH_COMMIT="3ff8c7e"
PACKAGES=("zsh" "oh-my-zsh" "jetbrains-mono-nerdfont" "terminus_font")

# Function to log messages
log() {
    echo "$@"
}

# Function to handle errors
error() {
    echo "❌ $1" >&2
    echo "❌ $1" >> "$NIX_LOG"
    exit 1
}

# Function to clean up on failure
cleanup() {
    log "❌ Error detected! Rolling back changes..."
    if [ -f "$STATE_DIR/installed_packages" ]; then
        log "🗑️ Removing installed packages..."
        mapfile -t pkgs < "$STATE_DIR/installed_packages"
        if [ ${#pkgs[@]} -gt 0 ]; then
            pacman -Rns --noconfirm "${pkgs[@]}" || log "⚠️ Failed to remove some packages, manual cleanup may be needed."
        fi
    fi
    if [ -f "$STATE_DIR/nix_installed" ]; then
        log "🗑️ Removing Nix..."
        if [ -f "/nix/var/nix/profiles/default/bin/nix-store" ]; then
            /nix/var/nix/profiles/default/bin/nix-collect-garbage -d
            systemctl stop nix-daemon.service || log "⚠️ Failed to stop nix-daemon."
            rm -rf /nix
            rm -rf "/home/$MAIN_USER/.nix-profile"
            rm -rf "/home/$MAIN_USER/.nix-defexpr"
            rm -rf "/home/$MAIN_USER/.nix-channels"
            rm -rf "/home/$MAIN_USER/.nix/registry.json"
            rm -rf "/home/$MAIN_USER/.config/nix"
            rm -rf "/home/$MAIN_USER/.config/nixpkgs"
            rm -rf /etc/nix
        fi
    fi
    if [ -f "$STATE_DIR/zshrc.bak" ]; then
        log "🔄 Restoring original .zshrc..."
        mv "$STATE_DIR/zshrc.bak" "/home/$MAIN_USER/.zshrc" || log "⚠️ Failed to restore .zshrc."
    fi
    if [ -f "$STATE_DIR/passwd.bak" ]; then
        log "🔄 Restoring original /etc/passwd..."
        mv "$STATE_DIR/passwd.bak" /etc/passwd || log "⚠️ Failed to restore /etc/passwd."
    fi
    if [ -f "$STATE_DIR/vconsole.conf.bak" ]; then
        log "🔄 Restoring original vconsole.conf..."
        mv "$STATE_DIR/vconsole.conf.bak" /etc/vconsole.conf || log "⚠️ Failed to restore vconsole.conf."
    fi
    if [ -s "$NIX_LOG" ]; then
        log "📜 Errors logged in $NIX_LOG:"
        cat "$NIX_LOG"
    fi
    rm -rf "$STATE_DIR"
    log "🔄 System restored to original state!"
    exit 1
}

# Set trap to call cleanup on any error
trap cleanup ERR

# Function: Check prerequisites
check_prerequisites() {
    log "🔍 [1/9] Checking prerequisites..."
    mkdir -p "$STATE_DIR"
    touch "$NIX_LOG"
    if [ ! "$(id -u "$MAIN_USER" 2>/dev/null)" ]; then
        error "User $MAIN_USER does not exist!"
    fi
    USER_HOME=$(getent passwd "$MAIN_USER" | cut -d: -f6)
    if [ ! -d "$USER_HOME" ]; then
        error "Home directory for $MAIN_USER ($USER_HOME) does not exist!"
    fi
    log "✅ User $MAIN_USER exists with home $USER_HOME"
    if ! ping -c 1 google.com >/dev/null 2>>"$NIX_LOG"; then
        error "No internet connection!"
    fi
    log "✅ Internet connection OK"
    if ! curl -L --head "$ZSH_URL" >/dev/null 2>>"$NIX_LOG"; then
        error "zsh-5.9 source URL ($ZSH_URL) is unreachable!"
    fi
    log "✅ zsh-5.9 source URL OK"
    if ! curl -L --head "$NIX_INSTALLER_URL" >/dev/null 2>>"$NIX_LOG"; then
        error "Nix installer URL ($NIX_INSTALLER_URL) is unreachable!"
    fi
    log "✅ Nix installer URL OK"
    if [ $(df / | tail -1 | awk '{print $4}') -lt 5000000 ]; then
        error "Less than 5GB free disk space on /!"
    fi
    log "✅ Sufficient disk space"
    if ! systemctl status >/dev/null 2>>"$NIX_LOG"; then
        error "Systemd not running, required for nix-daemon!"
    fi
    log "✅ Systemd OK"
    log "🔍 Prerequisites check complete"
}

# Function: Update Arch system
update_system() {
    log "🔄 [2/9] Updating Arch system..."
    pacman -Syu --noconfirm
    log "✅ System updated"
}

# Function: Install base packages
install_base_packages() {
    log "📦 [3/9] Installing base packages..."
    if pacman -Q git curl terminus-font xorg-mkfontscale >/dev/null 2>&1; then
        log "⚠️ Some base packages already installed."
    else
        echo "git curl terminus-font xorg-mkfontscale" > "$STATE_DIR/installed_packages"
        pacman -S --noconfirm git curl terminus-font xorg-mkfontscale
    fi
    log "✅ Base packages installed"
}

# Function: Install Nix package manager
install_nix() {
    log "🛠️ [4/9] Installing Nix package manager ($NIX_VERSION)..."
    if ! command -v nix >/dev/null; then
        curl -L "$NIX_INSTALLER_URL" -o "/tmp/nix-$NIX_VERSION.tar.xz" 2>&1 | tee -a "$NIX_LOG"
        log "🔍 Downloaded tarball SHA256:"
        sha256sum "/tmp/nix-$NIX_VERSION.tar.xz" | tee -a "$NIX_LOG"
        echo "$NIX_INSTALLER_SHA256  /tmp/nix-$NIX_VERSION.tar.xz" | sha256sum -c - 2>&1 | tee -a "$NIX_LOG" || 
            error "Nix installer SHA256 mismatch! Expected $NIX_INSTALLER_SHA256, see $NIX_LOG for actual."
        tar -xf "/tmp/nix-$NIX_VERSION.tar.xz" -C /tmp
        sh "/tmp/nix-$NIX_VERSION-x86_64-linux/install" --daemon --no-channel-add 2>&1 | tee -a "$NIX_LOG" || 
            error "Nix installation failed"
        rm -rf "/tmp/nix-$NIX_VERSION.tar.xz" "/tmp/nix-$NIX_VERSION-x86_64-linux"
        if [ ! -f /etc/profile.d/nix.sh ]; then
            error "Nix environment script not found!"
        fi
        source /etc/profile.d/nix.sh || error "Nix environment sourcing failed"
        if ! systemctl status nix-daemon.service >/dev/null 2>>"$NIX_LOG"; then
            error "nix-daemon not running!"
        fi
        touch "$STATE_DIR/nix_installed"
    else
        log "⚠️ Nix already installed, skipping."
    fi
    log "✅ Nix installed"
}

# Function: Configure Nix environment
configure_nix() {
    log "⚙️ [5/9] Configuring Nix environment..."
    mkdir -p /etc/nix
    cat << EOF > /etc/nix/nix.conf
experimental-features = nix-command flakes
substituters = https://cache.nixos.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
EOF
    systemctl restart nix-daemon.service 2>&1 | tee -a "$NIX_LOG" || error "Failed to restart nix-daemon"
    log "✅ Nix configured"
}

# Function: Pin Nixpkgs to 25.05
pin_nixpkgs() {
    log "📌 [6/9] Pinning nixpkgs to commit $NIXPKGS_COMMIT..."
    sudo -u "$MAIN_USER" bash -c "source /etc/profile.d/nix.sh && nix registry add nixpkgs github:NixOS/nixpkgs/$NIXPKGS_COMMIT" 2>&1 | tee -a "$NIX_LOG" || 
        error "Failed to pin nixpkgs to commit $NIXPKGS_COMMIT"
    log "✅ Nixpkgs pinned to commit $NIXPKGS_COMMIT"
}

# Function: Install Nix packages
install_packages() {
    log "🛠️ [7/9] Installing zsh-5.9, oh-my-zsh, and fonts..."
    mkdir -p "$NIX_CONFIG_DIR"
    chown "$MAIN_USER:$MAIN_USER" "$NIX_CONFIG_DIR"
    cat << EOF > "$NIX_CONFIG_DIR/config.nix"
{
  packageOverrides = pkgs: {
    zsh = pkgs.zsh.overrideAttrs (old: {
      version = "5.9";
      src = pkgs.fetchurl {
        url = "http://www.zsh.org/pub/zsh-5.9.tar.xz";
        sha256 = "9b8d1ecedd5b5e81fbf1918e876752a7dd948e05c1a0dba10ab863842d45acd5";
      };
    });
    oh-my-zsh = pkgs.oh-my-zsh.overrideAttrs (old: {
      src = pkgs.fetchFromGitHub {
        owner = "ohmyzsh";
        repo = "ohmyzsh";
        rev = "$OHMYZSH_COMMIT";
        sha256 = "1m3z4v3z4q3z4x7x0v3z4q3z4w0v3lw3p4n0i1w63lh3g6f3h5d2"; # Placeholder
      };
    });
    jetbrains-mono-nerdfont = pkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; };
    terminus_font = pkgs.terminus_font;
  };
}
EOF
    chown "$MAIN_USER:$MAIN_USER" "$NIX_CONFIG_DIR/config.nix"
    OHMYZSH_SHA256=$(sudo -u "$MAIN_USER" bash -c "source /etc/profile.d/nix.sh && nix-prefetch-url --type sha256 --unpack https://github.com/ohmyzsh/ohmyzsh/archive/$OHMYZSH_COMMIT.tar.gz" 2>>"$NIX_LOG")
    if [ -z "$OHMYZSH_SHA256" ]; then
        error "Failed to fetch sha256 for oh-my-zsh commit $OHMYZSH_COMMIT!"
    fi
    sed -i "s|sha256 = \"1m3z4v3z4q3z4x7x0v3z4q3z4w0v3lw3p4n0i1w63lh3g6f3h5d2\";|sha256 = \"$OHMYZSH_SHA256\";|" "$NIX_CONFIG_DIR/config.nix"
    for pkg in "${PACKAGES[@]}"; do
        sudo -u "$MAIN_USER" bash -c "source /etc/profile.d/nix.sh && nix-env -iA nixpkgs.$pkg" 2>&1 | tee -a "$NIX_LOG" || 
            error "Failed to install $pkg"
    done
    echo "zsh oh-my-zsh jetbrains-mono-nerdfont terminus_font" >> "$STATE_DIR/installed_packages"
    log "✅ Packages installed"
}

# Function: Configure fonts
configure_fonts() {
    log "⚙️ [8/9] Configuring Terminus font for virtual console and JetBrainsMono for GUI..."
    if [ -f /etc/vconsole.conf ]; then
        cp /etc/vconsole.conf "$STATE_DIR/vconsole.conf.bak"
    fi
    echo "FONT=ter-v16n" > /tmp/vconsole.conf
    mv /tmp/vconsole.conf /etc/vconsole.conf
    mkfontscale /usr/share/fonts/terminus 2>&1 | tee -a "$NIX_LOG"
    sudo -u "$MAIN_USER" bash -c "source /etc/profile.d/nix.sh && fc-cache -fv" 2>&1 | tee -a "$NIX_LOG"
    log "✅ Fonts configured"
}

# Function: Configure zsh
configure_zsh() {
    log "⚙️ [9/9] Configuring zsh for $MAIN_USER..."
    if [ ! -f "$ZSH_PATH" ]; then
        error "zsh not found at $ZSH_PATH!"
    fi
    cp /etc/passwd "$STATE_DIR/passwd.bak"
    chsh -s "$ZSH_PATH" "$MAIN_USER"
    if [ -f "$USER_HOME/.zshrc" ]; then
        cp "$USER_HOME/.zshrc" "$STATE_DIR/zshrc.bak"
    fi
    cat << EOF > "$USER_HOME/.zshrc"
# Oh My Zsh configuration
export ZSH="/nix/var/nix/profiles/default/share/oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source "\$ZSH/oh-my-zsh.sh"
export PATH="\$HOME/bin:/usr/local/bin:\$PATH"
alias ls='ls --color=auto'
alias ll='ls -l'
EOF
    chown "$MAIN_USER:$MAIN_USER" "$USER_HOME/.zshrc"
    log "✅ zsh configured"
}

# Function: Verify setup
verify_setup() {
    log "✅ Verifying configuration..."
    if ! "$ZSH_PATH" --version >/dev/null 2>>"$NIX_LOG"; then
        error "zsh binary not executable!"
    fi
    if ! "$ZSH_PATH" --version | grep -q "5.9"; then
        error "zsh version verification failed! Expected 5.9"
    fi
    if ! grep -q "$ZSH_PATH" /etc/passwd; then
        error "zsh not set as default shell!"
    fi
    if [ ! -d "/nix/var/nix/profiles/default/share/oh-my-zsh" ]; then
        error "oh-my-zsh not installed correctly!"
    fi
    if ! fc-list | grep -q "JetBrainsMono"; then
        error "JetBrainsMono Nerd Font not installed correctly!"
    fi
    log "✅ Setup verified"
}

# Main execution
log "🚀 Starting Arch Linux Setup for $MAIN_USER: Step 2 - Nix Package Manager (Nixpkgs 25.05)"
if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run with sudo!"
fi
check_prerequisites
update_system
install_base_packages
install_nix
configure_nix
pin_nixpkgs
install_packages
configure_fonts
configure_zsh
verify_setup
rm -rf "$STATE_DIR"
log "🎉 Setup complete: Nix with zsh-5.9, oh-my-zsh ($OHMYZSH_COMMIT), and fonts installed!"
log "ℹ️ JetBrains Mono Nerd Font installed for GUI terminals (configure manually)."
log "ℹ️ Virtual console uses Terminus font (ter-v16n)."
log "ℹ️ zsh is the default shell. Log out and log in to use."
log "ℹ️ Nixpkgs pinned to commit $NIXPKGS_COMMIT. Source /etc/profile.d/nix.sh to use Nix."
log "ℹ️ Nix config in $NIX_CONFIG_DIR for reproducibility."
log "ℹ️ If using XFCE, add xfce4-terminal config: echo '[Configuration]\nFontName=JetBrainsMono Nerd Font Bold 14' > ~/.config/xfce4/xfce4-terminal/terminalrc"