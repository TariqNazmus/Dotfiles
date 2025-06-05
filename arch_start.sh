#!/bin/bash

# Exit on error, unset variables, or pipeline failure
set -euo pipefail

# Constant for main user
MAIN_USER="sadat"

# Print a fun header 😎
echo "🚀 Starting Arch Linux Setup for $MAIN_USER: Step 2 - Nix Package Manager (Nixpkgs 25.05) 🚀"

# Directory to store temporary state for rollback
STATE_DIR="/tmp/arch_setup_state_nix"
mkdir -p "$STATE_DIR"

# Function to clean up on failure
cleanup() {
    echo "❌ Error detected! Rolling back changes... 🧹"

    # Remove installed packages if they were installed
    if [ -f "$STATE_DIR/installed_packages" ]; then
        echo "🗑️ Removing installed packages..."
        mapfile -t pkgs < "$STATE_DIR/installed_packages"
        if [ ${#pkgs[@]} -gt 0 ]; then
            pacman -Rns --noconfirm "${pkgs[@]}" || echo "⚠️ Failed to remove some packages, manual cleanup may be needed."
        fi
    fi

    # Remove paru if installed
    if [ -f "$STATE_DIR/paru_installed" ]; then
        echo "🗑️ Removing paru..."
        rm -rf "/home/$MAIN_USER/paru"
        pacman -Rns --noconfirm paru || echo "⚠️ Failed to remove paru, manual cleanup may be needed."
    fi

    # Remove Nix if installed
    if [ -f "$STATE_DIR/nix_installed" ]; then
        echo "🗑️ Removing Nix..."
        if [ -f "/nix/var/nix/profiles/default/bin/nix-store" ]; then
            /nix/var/nix/profiles/default/bin/nix-collect-garbage -d
            rm -rf /nix
            rm -rf "/home/$MAIN_USER/.nix-profile"
            rm -rf "/home/$MAIN_USER/.nix-defexpr"
            rm -rf "/home/$MAIN_USER/.nix-channels"
            rm -f "/home/$MAIN_USER/.config/nix/nix.conf"
        fi
    fi

    # Restore original vconsole.conf if backed up
    if [ -f "$STATE_DIR/vconsole.conf.bak" ]; then
        echo "🔄 Restoring original vconsole.conf..."
        mv "$STATE_DIR/vconsole.conf.bak" /etc/vconsole.conf || echo "⚠️ Failed to restore vconsole.conf."
    fi

    # Remove terminal configuration if created
    if [ -f "$STATE_DIR/xfce4-terminal-config.bak" ]; then
        echo "🔄 Restoring original xfce4-terminal configuration..."
        mv "$STATE_DIR/xfce4-terminal-config.bak" "/home/$MAIN_USER/.config/xfce4/xfce4-terminal/terminalrc" || echo "⚠️ Failed to restore xfce4-terminal config."
    elif [ -f "/home/$MAIN_USER/.config/xfce4/xfce4-terminal/terminalrc" ]; then
        rm -f "/home/$MAIN_USER/.config/xfce4/xfce4-terminal/terminalrc"
    fi

    # Clean up state directory
    rm -rf "$STATE_DIR"
    echo "🔄 System restored to original state! 🎉"
    exit 1
}

# Set trap to call cleanup on any error
trap cleanup ERR

# Step 1: Verify main user exists
echo "🔍 Verifying user $MAIN_USER exists..."
id "$MAIN_USER" &>/dev/null || {
    echo "❌ User $MAIN_USER does not exist! Please create the user first."
    exit 1
}
USER_HOME=$(getent passwd "$MAIN_USER" | cut -d: -f6)
[ -d "$USER_HOME" ] || {
    echo "❌ Home directory for $MAIN_USER ($USER_HOME) does not exist!"
    exit 1
}

# Step 2: Update Arch system
echo "🔄 Updating Arch system..."
pacman -Syu --noconfirm

# Step 3: Check for existing packages and Nix
echo "🔍 Checking for existing packages..."
pacman -Q base-devel git curl terminus-font xorg-mkfontscale ttf-jetbrains-mono-nerd > /dev/null 2>&1 && {
    echo "⚠️ Some base packages already installed."
} || {
    echo "📦 Installing base-devel, git, curl, terminus-font, and xorg-mkfontscale..."
    echo "base-devel git curl terminus-font xorg-mkfontscale" > "$STATE_DIR/installed_packages"
    pacman -S --noconfirm base-devel git curl terminus-font xorg-mkfontscale
}

echo "🔍 Checking for existing Nix installation..."
if command -v nix > /dev/null 2>&1; then
    echo "⚠️ Nix is already installed, skipping installation."
    exit 0
fi

# Step 4: Install paru (AUR helper) for JetBrains Mono Nerd Font
echo "🛠️ Installing paru for AUR package management..."
if ! command -v paru > /dev/null; then
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
    echo "ttf-jetbrains-mono-nerd" >> "$STATE_DIR/installed_packages"
    sudo -u "$MAIN_USER" paru -S --noconfirm ttf-jetbrains-mono-nerd
}

# Step 6: Apply font to virtual console
echo "⚙️ Configuring Terminus font for virtual console (Nerd Fonts not supported in vconsole)..."
if [ -f /etc/vconsole.conf ]; then
    cp /etc/vconsole.conf "$STATE_DIR/vconsole.conf.bak"
}
echo "FONT=ter-v16n" > /etc/vconsole.conf
mkfontscale /usr/share/fonts/terminus
fc-cache -fv

# Step 7: Configure JetBrains Mono Nerd Font for GUI terminals (example: xfce4-terminal)
echo "⚙️ Configuring JetBrains Mono Nerd Font for xfce4-terminal..."
mkdir -p "$USER_HOME/.config/xfce4/xfce4-terminal"
chown "$MAIN_USER:$MAIN_USER" "$USER_HOME/.config/xfce4" "$USER_HOME/.config/xfce4/xfce4-terminal"
if [ -f "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc" ]; then
    cp "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc" "$STATE_DIR/xfce4-terminal-config.bak"
}
cat << EOF > "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc"
[Configuration]
FontName=JetBrainsMono Nerd Font 12
EOF
chown "$MAIN_USER:$MAIN_USER" "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc"

# Step 8: Install Nix package manager
echo "🛠️ Installing Nix package manager..."
sudo -u "$MAIN_USER" sh -c "curl -L https://nixos.org/nix/install | sh -s -- --no-daemon"
touch "$STATE_DIR/nix_installed"

# Step 9: Source Nix environment for the current session
echo "🔧 Sourcing Nix environment..."
if [ -f "/home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh" ]; then
    source "/home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh"
else
    echo "❌ Failed to find Nix environment script!"
    exit 1
}

# Step 10: Configure Nix with pinned Nixpkgs version
echo "📝 Configuring Nix with pinned Nixpkgs version (25.05)..."
mkdir -p "/home/$MAIN_USER/.config/nix"
chown "$MAIN_USER:$MAIN_USER" "/home/$MAIN_USER/.config/nix"
cat << EOF > "/home/$MAIN_USER/.config/nix/nix.conf"
experimental-features = nix-command flakes
substituters = https://cache.nixos.org/
trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
EOF
chown "$MAIN_USER:$MAIN_USER" "/home/$MAIN_USER/.config/nix/nix.conf"

# Pin Nixpkgs to 25.05
sudo -u "$MAIN_USER" nix-channel --add https://github.com/NixOS/nixpkgs/archive/25.05.tar.gz nixpkgs
sudo -u "$MAIN_USER" nix-channel --update

# Step 11: Verify Nix installation
echo "✅ Verifying Nix installation..."
nix --version > /dev/null || {
    echo "❌ Nix installation verification failed!"
    exit 1
}
sudo -u "$MAIN_USER" nix-channel --list | grep "nixpkgs.*25.05" > /dev/null || {
    echo "❌ Nixpkgs version pinning verification failed!"
    exit 1
}

# Step 12: Clean up state if successful
rm -rf "$STATE_DIR"
echo "🎉 Step 2 complete: Nix package manager installed and configured with Nixpkgs 25.05! 🚀"
echo "ℹ️ JetBrains Mono Nerd Font applied to xfce4-terminal. For other GUI terminals (e.g., GNOME Terminal, Kitty), manually set 'JetBrainsMono Nerd Font' in their preferences."
echo "ℹ️ Virtual console uses Terminus font (ter-v16n) as Nerd Fonts are not supported in vconsole."
echo "ℹ️ Nix is set up with Nixpkgs 25.05. Source ~/.nix-profile/etc/profile.d/nix.sh in your shell or restart your session to use Nix."