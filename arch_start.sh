#!/bin/bash

# Exit on error, unset variables, or pipeline failure
set -euo pipefail

# Constant for main user
MAIN_USER="sadat"

# Print a fun header 😎
echo "🚀 Starting Arch Linux Setup for $MAIN_USER: Step 1 - System Update, Base Packages & JetBrains Mono Nerd Font 🚀"

# Directory to store temporary state for rollback
STATE_DIR="/tmp/arch_setup_state"
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

# Step 3: Check for existing packages to avoid unnecessary installs
echo "🔍 Checking for existing packages..."
pacman -Q base-devel git curl terminus-font ttf-jetbrains-mono-nerd > /dev/null 2>&1 && {
    echo "⚠️ Some packages already installed, skipping installation."
    exit 0
}

# Step 4: Install base-devel, git, curl, and terminus-font (for virtual console)
echo "📦 Installing base-devel, git, curl, and terminus-font..."
echo "base-devel git curl terminus-font" > "$STATE_DIR/installed_packages"
pacman -S --noconfirm base-devel git curl terminus-font

# Step 5: Install paru (AUR helper) for JetBrains Mono Nerd Font
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

# Step 6: Install JetBrains Mono Nerd Font
echo "🖌️ Installing JetBrains Mono Nerd Font..."
echo "ttf-jetbrains-mono-nerd" >> "$STATE_DIR/installed_packages"
sudo -u "$MAIN_USER" paru -S --noconfirm ttf-jetbrains-mono-nerd

# Step 7: Apply font to virtual console
echo "⚙️ Configuring Terminus font for virtual console (Nerd Fonts not supported in vconsole)..."
if [ -f /etc/vconsole.conf ]; then
    cp /etc/vconsole.conf "$STATE_DIR/vconsole.conf.bak"
fi
echo "FONT=ter-v16n" > /etc/vconsole.conf
mkfontdir /usr/share/fonts/terminus
fc-cache -fv

# Step 8: Configure JetBrains Mono Nerd Font for GUI terminals (example: xfce4-terminal)
echo "⚙️ Configuring JetBrains Mono Nerd Font for xfce4-terminal..."
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

# Step 9: Verify installations
echo "✅ Verifying installed packages..."
for pkg in git curl terminus-font ttf-jetbrains-mono-nerd; do
    pacman -Q "$pkg" > /dev/null || {
        echo "❌ Verification failed for $pkg!"
        exit 1
    }
done

# Step 10: Clean up state if successful
rm -rf "$STATE_DIR"
echo "🎉 Step 1 complete: System updated, base packages, and JetBrains Mono Nerd Font installed! 🚀"
echo "ℹ️ JetBrains Mono Nerd Font applied to xfce4-terminal. For other GUI terminals (e.g., GNOME Terminal, Kitty), manually set 'JetBrainsMono Nerd Font' in their preferences."
echo "ℹ️ Virtual console uses Terminus font (ter-v16n) as Nerd Fonts are not supported in vconsole."