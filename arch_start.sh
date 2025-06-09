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

# Print a fun header 😎
echo "🚀 Starting Arch Linux Setup for $MAIN_USER: Step 2 - Nix Package Manager (Nixpkgs 25.05) 🚀"

# Directory to store temporary state for rollback
STATE_DIR="/tmp/arch_setup_state_nix"
mkdir -p "$STATE_DIR"

# Progress bar function
progress_bar() {
    local duration=$1
    local message=$2
    local width=50
    local percent=0
    local filled=0
    local empty=$((width - filled))

    printf "\r$message ["
    printf "%${filled}s" | tr ' ' '#'
    printf "%${empty}s" | tr ' ' '-'
    printf "] %d%%" $percent

    for ((i = 1; i <= duration; i++)); do
        sleep $((duration / 100))
        percent=$((i * 100 / duration))
        filled=$((width * i / duration))
        empty=$((width - filled))
        printf "\r$message ["
        printf "%${filled}s" | tr ' ' '#'
        printf "%${empty}s" | tr ' ' '-'
        printf "] %d%%" $percent
    done
    printf "\n"
}

# Function to clean up on failure
cleanup() {
    echo "❌ Error detected! Rolling back changes... 🧹"
    progress_bar 5 "Cleaning up..."

    if [ -f "$STATE_DIR/installed_packages" ]; then
        echo "🗑️ Removing installed packages..."
        mapfile -t pkgs < "$STATE_DIR/installed_packages"
        if [ ${#pkgs[@]} -gt 0 ]; then
            pacman -Rns --noconfirm "${pkgs[@]}" || echo "⚠️ Failed to remove some packages, manual cleanup may be needed."
        fi
    fi

    if [ -f "$STATE_DIR/paru_installed" ]; then
        echo "🗑️ Removing paru..."
        rm -rf "/home/$MAIN_USER/paru"
        pacman -Rns --noconfirm paru || echo "⚠️ Failed to remove paru, manual cleanup may be needed."
    fi

    if [ -f "$STATE_DIR/nix_installed" ]; then
        echo "🗑️ Removing Nix..."
        if [ -f "/nix/var/nix/profiles/default/bin/nix-store" ]; then
            /nix/var/nix/profiles/default/bin/nix-collect-garbage -d
            rm -rf /nix
            rm -rf "/home/$MAIN_USER/.nix-profile"
            rm -rf "/home/$MAIN_USER/.nix-defexpr"
            rm -rf "/home/$MAIN_USER/.nix-channels"
            rm -f "/home/$MAIN_USER/.config/nix/nix.conf"
            rm -f "/home/$MAIN_USER/.config/nix/nixpkgs-sha256"
        fi
    fi

    if [ -f "$STATE_DIR/vconsole.conf.bak" ]; then
        echo "🔄 Restoring original vconsole.conf..."
        mv "$STATE_DIR/vconsole.conf.bak" /etc/vconsole.conf || echo "⚠️ Failed to restore vconsole.conf."
    fi

    if [ -f "$STATE_DIR/xfce4-terminal-config.bak" ]; then
        echo "🔄 Restoring original xfce4-terminal configuration..."
        mv "$STATE_DIR/xfce4-terminal-config.bak" "/home/$MAIN_USER/.config/xfce4/xfce4-terminal/terminalrc" || echo "⚠️ Failed to restore xfce4-terminal config."
    elif [ -f "/home/$MAIN_USER/.config/xfce4/xfce4-terminal/terminalrc" ]; then
        rm -f "/home/$MAIN_USER/.config/xfce4/xfce4-terminal/terminalrc"
    fi

    rm -rf "$STATE_DIR"
    echo "🔄 System restored to original state! 🎉"
    exit 1
}

# Set trap to call cleanup on any error
trap cleanup ERR

# Step 1: Verify main user exists
echo "🔍 Verifying user $MAIN_USER exists..."
progress_bar 2 "Checking user..."
if [ ! "$(id -u "$MAIN_USER" 2>/dev/null)" ]; then
    echo "❌ User $MAIN_USER does not exist! Please create the user first."
    exit 1
fi
USER_HOME=$(getent passwd "$MAIN_USER" | cut -d: -f6)
if [ ! -d "$USER_HOME" ]; then
    echo "❌ Home directory for $MAIN_USER ($USER_HOME) does not exist!"
    exit 1
fi

# Step 2: Update Arch system
echo "🔄 Updating Arch system..."
progress_bar 10 "Updating system..."
pacman -Syu --noconfirm

# Step 3: Check for existing packages and Nix
echo "🔍 Checking for existing packages..."
progress_bar 5 "Checking packages..."
if pacman -Q base-devel git curl terminus-font xorg-mkfontscale ttf-jetbrains-mono-nerd > /dev/null 2>&1; then
    echo "⚠️ Some base packages already installed."
else
    echo "📦 Installing base-devel, git, curl, terminus-font, and xorg-mkfontscale..."
    progress_bar 10 "Installing base packages..."
    echo "base-devel git curl terminus-font xorg-mkfontscale" > "$STATE_DIR/installed_packages"
    pacman -S --noconfirm base-devel git curl terminus-font xorg-mkfontscale
fi

echo "🔍 Checking for existing Nix installation..."
if [ -f "/home/$MAIN_USER/.nix-profile/bin/nix" ]; then
    echo "⚠️ Nix is already installed, skipping installation."
    exit 0
fi

# Step 4: Install paru (AUR helper) for JetBrains Mono Nerd Font
echo "🛠️ Installing paru for AUR package management..."
if ! command -v paru > /dev/null; then
    progress_bar 10 "Installing paru..."
    cd "$USER_HOME"
    sudo -u "$MAIN_USER" git clone https://aur.archlinux.org/paru.git
    cd paru
    sudo -u "$MAIN_USER" makepkg -si --noconfirm
    cd "$USER_HOME"
    rm -rf paru
    touch "$STATE_DIR/paru_installed"
fi

# Step 5: Install JetBrains Mono Nerd Font
echo "🖌️ Installing JetBrains Mono Nerd Font..."
if ! pacman -Q ttf-jetbrains-mono-nerd > /dev/null 2>&1; then
    progress_bar 10 "Installing JetBrains Mono Nerd Font..."
    echo "ttf-jetbrains-mono-nerd" >> "$STATE_DIR/installed_packages"
    sudo -u "$MAIN_USER" paru -S --noconfirm ttf-jetbrains-mono-nerd
fi

# Step 6: Apply font to virtual console
echo "⚙️ Configuring Terminus font for virtual console (Nerd Fonts not supported in vconsole)..."
progress_bar 5 "Configuring virtual console font..."
if [ -f /etc/vconsole.conf ]; then
    cp /etc/vconsole.conf "$STATE_DIR/vconsole.conf.bak"
fi
echo "FONT=ter-v16n" > /etc/vconsole.conf
mkfontscale /usr/share/fonts/terminus
fc-cache -fv

# Step 7: Configure JetBrains Mono Nerd Font for GUI terminals (example: xfce4-terminal)
echo "⚙️ Configuring JetBrains Mono Nerd Font for xfce4-terminal..."
progress_bar 5 "Configuring GUI terminal font..."
mkdir -p "$USER_HOME/.config/xfce4/xfce4-terminal"
chown "$MAIN_USER:$MAIN_USER" "$USER_HOME/.config/xfce4" "$USER_HOME/.config/xfce4/xfce4-terminal"
if [ -f "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc" ]; then
    cp "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc" "$STATE_DIR/xfce4-terminal-config.bak"
fi
cat << EOF > "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc"
[Configuration]
FontName=JetBrainsMono Nerd Font 12
EOF
chown "$MAIN_USER:$MAIN_USER" "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc"

# Step 8: Install Nix package manager
echo "🛠️ Installing Nix package manager..."
progress_bar 20 "Installing Nix..."
sudo -u "$MAIN_USER" sh -c "curl -L https://nixos.org/nix/install | sh -s -- --no-daemon"
touch "$STATE_DIR/nix_installed"

# Step 9: Verify Nix installation
echo "✅ Verifying Nix installation files..."
progress_bar 5 "Verifying Nix..."
if [ ! -d "/nix/store" ]; then
    echo "❌ Nix store (/nix/store) not found!"
    exit 1
fi
if [ ! -f "/home/$MAIN_USER/.nix-profile/bin/nix" ]; then
    echo "❌ Nix binary not found in user profile!"
    exit 1
fi

# Step 10: Source Nix environment for the current session
echo "🔧 Sourcing Nix environment..."
progress_bar 5 "Sourcing Nix environment..."
if [ -f "/home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh" ]; then
    source "/home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh"
else
    echo "❌ Failed to find Nix environment script!"
    exit 1
fi

# Step 11: Configure Nix with pinned Nixpkgs version
echo "📝 Configuring Nix with pinned Nixpkgs version (25.05)..."
progress_bar 10 "Configuring Nix..."
mkdir -p "/home/$MAIN_USER/.config/nix"
chown "$MAIN_USER:$MAIN_USER" "$USER_HOME/.config/nix"
cat << EOF > "/home/$MAIN_USER/.config/nix/nix.conf"
experimental-features = nix-command flakes
substituters = https://cache.nixos.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
EOF
chown "$MAIN_USER:$MAIN_USER" "/home/$MAIN_USER/.config/nix/nix.conf"

# Fetch sha256 for Nixpkgs 25.05 tarball
NIXPKGS_URL="https://github.com/NixOS/nixpkgs/archive/25.05.tar.gz"
NIXPKGS_SHA256=$(sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-prefetch-url --type sha256 --print-sri \"$NIXPKGS_URL\"" 2>/dev/null)
if [ -z "$NIXPKGS_SHA256" ]; then
    echo "❌ Failed to fetch sha256 for Nixpkgs 25.05 tarball!"
    exit 1
fi
echo "$NIXPKGS_SHA256" > "/home/$MAIN_USER/.config/nix/nixpkgs-sha256"
chown "$MAIN_USER:$MAIN_USER" "/home/$MAIN_USER/.config/nix/nixpkgs-sha256"

# Pin Nixpkgs to 25.05
sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-channel --add \"$NIXPKGS_URL\" nixpkgs"
sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-channel --update"

# Step 12: Verify Nix configuration
echo "✅ Verifying Nix configuration..."
progress_bar 5 "Verifying Nix configuration..."
if ! /home/$MAIN_USER/.nix-profile/bin/nix --version > /dev/null; then
    echo "❌ Nix installation verification failed!"
    exit 1
fi
if ! sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-channel --list" | grep "nixpkgs.*25.05" > /dev/null; then
    echo "❌ Nixpkgs version pinning verification failed!"
    exit 1
fi

# Step 13: Clean up state if successful
rm -rf "$STATE_DIR"
echo "🎉 Step 2 complete: Nix package manager installed and configured with Nixpkgs 25.05! 🚀"
echo "ℹ️ JetBrains Mono Nerd Font applied to xfce4-terminal. For other GUI terminals (e.g., GNOME Terminal, Kitty), manually set 'JetBrainsMono Nerd Font' in their preferences."
echo "ℹ️ Virtual console uses Terminus font (ter-v16n) as Nerd Fonts are not supported in vconsole."
echo "ℹ️ Nix is set up with Nixpkgs 25.05. Source ~/.nix-profile/etc/profile.d/nix.sh in your shell or restart your session to use Nix."