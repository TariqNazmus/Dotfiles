#!/bin/bash

# Exit on error, unset variables, or pipeline failure
set -euo pipefail

# Constant for main user
MAIN_USER="sadat"

# Check if running with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run with sudo! Run as: sudo bash setup-arch-step2-nix.sh"
    exit 1
fi

# Log file for errors
STATE_DIR="/tmp/arch_setup_state_nix"
NIX_LOG="$STATE_DIR/nix_errors.log"
mkdir -p "$STATE_DIR"
touch "$NIX_LOG"

# Function to clean up on failure
cleanup() {
    echo "❌ Error detected! Rolling back changes..."
    if [ -f "$STATE_DIR/installed_packages" ]; then
        echo "🗑️ Removing installed packages..."
        mapfile -t pkgs < "$STATE_DIR/installed_packages"
        if [ ${#pkgs[@]} -gt 0 ]; then
            pacman -Rns --noconfirm "${pkgs[@]}" || echo "⚠️ Failed to remove some packages, manual cleanup may be needed."
        fi
    fi
    if [ -f "$STATE_DIR/nix_installed" ]; then
        echo "🗑️ Removing Nix..."
        if [ -f "/nix/var/nix/profiles/default/bin/nix-store" ]; then
            /nix/var/nix/profiles/default/bin/nix-collect-garbage -d
            rm -rf /nix
            rm -rf "/home/$MAIN_USER/.nix-profile"
            rm -rf "/home/$MAIN_USER/.nix-defexpr"
            rm -rf "/home/$MAIN_USER/.nix-channels"
            rm -rf "/home/$MAIN_USER/.config/nix"
            rm -rf "/home/$MAIN_USER/.config/nixpkgs"
        fi
    fi
    if [ -f "$STATE_DIR/zshrc.bak" ]; then
        echo "🔄 Restoring original .zshrc..."
        mv "$STATE_DIR/zshrc.bak" "/home/$MAIN_USER/.zshrc" || echo "⚠️ Failed to restore .zshrc."
    fi
    if [ -f "$STATE_DIR/passwd.bak" ]; then
        echo "🔄 Restoring original /etc/passwd..."
        mv "$STATE_DIR/passwd.bak" /etc/passwd || echo "⚠️ Failed to restore /etc/passwd."
    fi
    if [ -f "$STATE_DIR/vconsole.conf.bak" ]; then
        echo "🔄 Restoring original vconsole.conf..."
        mv "$STATE_DIR/vconsole.conf.bak" /etc/vconsole.conf || echo "⚠️ Failed to restore vconsole.conf."
    fi
    if [ -s "$NIX_LOG" ]; then
        echo "📜 Errors logged in $NIX_LOG:"
        cat "$NIX_LOG"
    fi
    rm -rf "$STATE_DIR"
    echo "🔄 System restored to original state!"
    exit 1
}

# Set trap to call cleanup on any error
trap cleanup ERR

# Step 1: Pre-checks
echo "🔍 Running pre-checks..."
if [ ! "$(id -u "$MAIN_USER" 2>/dev/null)" ]; then
    echo "❌ User $MAIN_USER does not exist!" >> "$NIX_LOG"
    exit 1
fi
USER_HOME=$(getent passwd "$MAIN_USER" | cut -d: -f6)
if [ ! -d "$USER_HOME" ]; then
    echo "❌ Home directory for $MAIN_USER ($USER_HOME) does not exist!" >> "$NIX_LOG"
    exit 1
fi
if ! ping -c 1 google.com >/dev/null 2>&1; then
    echo "❌ No internet connection!" >> "$NIX_LOG"
    exit 1
fi
if [ $(df / | tail -1 | awk '{print $4}') -lt 5000000 ]; then
    echo "❌ Less than 5GB free disk space on /!" >> "$NIX_LOG"
    exit 1
fi
ZSH_URL="http://www.zsh.org/pub/zsh-5.9.tar.xz"
if ! curl -L --head "$ZSH_URL" >/dev/null 2>&1; then
    echo "❌ zsh-5.9 source URL ($ZSH_URL) is unreachable!" >> "$NIX_LOG"
    exit 1
fi

# Step 2: Update Arch system
echo "🔄 Updating Arch system..."
pacman -Syu --noconfirm >> "$NIX_LOG" 2>&1

# Step 3: Install base packages
echo "📦 Installing base packages..."
if pacman -Q git curl terminus-font xorg-mkfontscale >/dev/null 2>&1; then
    echo "⚠️ Some base packages already installed."
else
    echo "git curl terminus-font xorg-mkfontscale" > "$STATE_DIR/installed_packages"
    pacman -S --noconfirm git curl terminus-font xorg-mkfontscale >> "$NIX_LOG" 2>&1
fi

# Step 4: Install Nix package manager
echo "🛠️ Installing Nix package manager..."
if ! command -v nix >/dev/null; then
    sh -c "curl -L https://nixos.org/nix/install | sh -s -- --no-daemon" >> "$NIX_LOG" 2>&1
    touch "$STATE_DIR/nix_installed"
fi

# Step 5: Source Nix environment
echo "🔧 Sourcing Nix environment..."
if [ -f "/home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh" ]; then
    source "/home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh"
else
    echo "❌ Failed to find Nix environment script!" >> "$NIX_LOG"
    exit 1
fi

# Step 6: Configure Nix with pinned Nixpkgs 25.05
echo "📝 Configuring Nix with pinned Nixpkgs 25.05..."
mkdir -p "/home/$MAIN_USER/.config/nix"
chown "$MAIN_USER:$MAIN_USER" "$USER_HOME/.config/nix"
cat << EOF > "/home/$MAIN_USER/.config/nix/nix.conf"
experimental-features = nix-command flakes
substituters = https://cache.nixos.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
EOF
chown "$MAIN_USER:$MAIN_USER" "/home/$MAIN_USER/.config/nix/nix.conf"

NIX_CONFIG_DIR="/home/$MAIN_USER/.config/nixpkgs"
mkdir -p "$NIX_CONFIG_DIR"
chown "$MAIN_USER:$MAIN_USER" "$NIX_CONFIG_DIR"
cat << EOF > "$NIX_CONFIG_DIR/config.nix"
let
  nixpkgs = import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/25.05.tar.gz";
    sha256 = "0w0v3lw3p4n0i1w63lh3g6f3h5d2c0g6b3z4q3z4x7x0v3z4q3z4"; # Placeholder
  }) {};
in
{
  environment.systemPackages = with nixpkgs; [
    (nixpkgs.zsh.overrideAttrs (old: {
      version = "5.9";
      src = fetchurl {
        url = "http://www.zsh.org/pub/zsh-5.9.tar.xz";
        sha256 = "9b8d1ecedd5b5e81fbf1918e876752a7dd948e05c1a0dba10ab863842d45acd5";
      };
    }))
    (nixpkgs.oh-my-zsh.overrideAttrs (old: {
      src = fetchFromGitHub {
        owner = "ohmyzsh";
        repo = "ohmyzsh";
        rev = "3ff8c7e";
        sha256 = "1m3z4v3z4q3z4x7x0v3z4q3z4w0v3lw3p4n0i1w63lh3g6f3h5d2"; # Placeholder
      };
    }))
    nixpkgs.nerdfonts.override { fonts = [ "JetBrainsMono" ]; }
    nixpkgs.terminus_font
  ];
}
EOF
chown "$MAIN_USER:$MAIN_USER" "$NIX_CONFIG_DIR/config.nix"

# Fetch sha256 for Nixpkgs 25.05 with retries
NIXPKGS_URL="https://github.com/NixOS/nixpkgs/archive/25.05.tar.gz"
for attempt in {1..3}; do
    echo "🔍 Attempt $attempt to fetch Nixpkgs 25.05 sha256..."
    NIXPKGS_SHA256=$(nix-prefetch-url --type sha256 "$NIXPKGS_URL" 2>>"$NIX_LOG")
    if [ -n "$NIXPKGS_SHA256" ]; then
        break
    fi
    echo "⚠️ Failed to fetch sha256 on attempt $attempt. Retrying in 5 seconds..."
    sleep 5
done
if [ -z "$NIXPKGS_SHA256" ]; then
    echo "❌ Failed to fetch sha256 for Nixpkgs 25.05!" >> "$NIX_LOG"
    exit 1
fi
sed -i "s|sha256 = \"0w0v3lw3p4n0i1w63lh3g6f3h5d2c0g6b3z4q3z4x7x0v3z4q3z4\";|sha256 = \"$NIXPKGS_SHA256\";|" "$NIX_CONFIG_DIR/config.nix"

# Fetch sha256 for oh-my-zsh commit 3ff8c7e
for attempt in {1..3}; do
    echo "🔍 Attempt $attempt to fetch oh-my-zsh sha256..."
    OHMYZSH_SHA256=$(nix-prefetch-url --type sha256 --unpack "https://github.com/ohmyzsh/ohmyzsh/archive/3ff8c7e.tar.gz" 2>>"$NIX_LOG")
    if [ -n "$OHMYZSH_SHA256" ]; then
        break
    fi
    echo "⚠️ Failed to fetch sha256 on attempt $attempt. Retrying in 5 seconds..."
    sleep 5
done
if [ -z "$OHMYZSH_SHA256" ]; then
    echo "❌ Failed to fetch sha256 for oh-my-zsh commit 3ff8c7e!" >> "$NIX_LOG"
    exit 1
fi
sed -i "s|sha256 = \"1m3z4v3z4q3z4x7x0v3z4q3z4w0v3lw3p4n0i1w63lh3g6f3h5d2\";|sha256 = \"$OHMYZSH_SHA256\";|" "$NIX_CONFIG_DIR/config.nix"

# Step 7: Install packages via Nix
echo "🛠️ Installing zsh-5.9, oh-my-zsh, and fonts via Nix..."
sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-env -iA nixpkgs.zsh nixpkgs.oh-my-zsh nixpkgs.nerdfonts nixpkgs.terminus_font" >> "$NIX_LOG" 2>&1
echo "zsh oh-my-zsh nerdfonts terminus_font" >> "$STATE_DIR/installed_packages"

# Step 8: Configure zsh as default shell
echo "⚙️ Setting zsh as default shell for $MAIN_USER..."
ZSH_PATH="/home/$MAIN_USER/.nix-profile/bin/zsh"
if [ ! -f "$ZSH_PATH" ]; then
    echo "❌ zsh not found at $ZSH_PATH!" >> "$NIX_LOG"
    exit 1
fi
cp /etc/passwd "$STATE_DIR/passwd.bak"
chsh -s "$ZSH_PATH" "$MAIN_USER"

# Step 9: Configure .zshrc
echo "⚙️ Configuring .zshrc for $MAIN_USER..."
if [ -f "$USER_HOME/.zshrc" ]; then
    cp "$USER_HOME/.zshrc" "$STATE_DIR/zshrc.bak"
fi
cat << EOF > "$USER_HOME/.zshrc"
# Oh My Zsh configuration
export ZSH="/home/$MAIN_USER/.nix-profile/share/oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source "\$ZSH/oh-my-zsh.sh"
export PATH="\$HOME/bin:/usr/local/bin:\$PATH"
alias ls='ls --color=auto'
alias ll='ls -l'
EOF
chown "$MAIN_USER:$MAIN_USER" "$USER_HOME/.zshrc"

# Step 10: Configure virtual console font
echo "⚙️ Configuring Terminus font for virtual console..."
if [ -f /etc/vconsole.conf ]; then
    cp /etc/vconsole.conf "$STATE_DIR/vconsole.conf.bak"
fi
echo "FONT=ter-v16n" > /etc/vconsole.conf
mkfontscale /usr/share/fonts/terminus
fc-cache -fv

# Step 11: Verify configuration
echo "✅ Verifying configuration..."
if ! "$ZSH_PATH" --version >/dev/null 2>&1; then
    echo "❌ zsh binary not executable!" >> "$NIX_LOG"
    exit 1
fi
if ! "$ZSH_PATH" --version | grep -q "5.9"; then
    echo "❌ zsh version verification failed! Expected 5.9" >> "$NIX_LOG"
    exit 1
fi
if ! grep -q "$ZSH_PATH" /etc/passwd; then
    echo "❌ zsh not set as default shell!" >> "$NIX_LOG"
    exit 1
fi
if [ ! -d "/home/$MAIN_USER/.nix-profile/share/oh-my-zsh" ]; then
    echo "❌ oh-my-zsh not installed correctly!" >> "$NIX_LOG"
    exit 1
fi

# Step 12: Clean up state if successful
rm -rf "$STATE_DIR"
echo "🎉 Setup complete: Nix with zsh-5.9, oh-my-zsh (commit 3ff8c7e), and fonts installed!"
echo "ℹ️ JetBrains Mono Nerd Font installed for GUI terminals (configure manually in your terminal emulator)."
echo "ℹ️ Virtual console uses Terminus font (ter-v16n)."
echo "ℹ️ zsh is the default shell for $MAIN_USER. Log out and log in to use it."
echo "ℹ️ Nixpkgs pinned to 25.05. Source ~/.nix-profile/etc/profile.d/nix.sh to use Nix."
echo "ℹ️ Nix config in $NIX_CONFIG_DIR for reproducibility."
echo "ℹ️ If using XFCE later, add xfce4-terminal config: echo '[Configuration]\nFontName=JetBrainsMono Nerd Font Bold 14' > ~/.config/xfce4/xfce4-terminal/terminalrc"