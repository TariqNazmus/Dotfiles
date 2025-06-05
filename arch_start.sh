#!/bin/bash

# Exit on error, unset variables, or pipeline failure
set -euo pipefail

# Print a fun header 😎
echo "🚀 Starting Arch Linux Setup: Step 1 - System Update, Base Packages & FiraCode Nerd Font 🚀"

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
        rm -rf /tmp/paru
        userdel -r paruuser || echo "⚠️ Failed to remove paruuser, manual cleanup may be needed."
        rm -f /etc/sudoers.d/paruuser
    fi

    # Restore original vconsole.conf if backed up
    if [ -f "$STATE_DIR/vconsole.conf.bak" ]; then
        echo "🔄 Restoring original vconsole.conf..."
        mv "$STATE_DIR/vconsole.conf.bak" /etc/vconsole.conf || echo "⚠️ Failed to restore vconsole.conf."
    fi

    # Remove terminal configuration if created
    if [ -f "$STATE_DIR/xfce4-terminal-config.bak" ]; then
        echo "🔄 Restoring original xfce4-terminal configuration..."
        mv "$STATE_DIR/xfce4-terminal-config.bak" ~/.config/xfce4/xfce4-terminal/terminalrc || echo "⚠️ Failed to restore xfce4-terminal config."
    elif [ -f ~/.config/xfce4/xfce4-terminal/terminalrc ]; then
        rm -f ~/.config/xfce4/xfce4-terminal/terminalrc
    fi

    # Clean up state directory
    rm -rf "$STATE_DIR"
    echo "🔄 System restored to original state! 🎉"
    exit 1
}

# Set trap to call cleanup on any error
trap cleanup ERR

# Step 1: Update Arch system
echo "🔄 Updating Arch system..."
pacman -Syu --noconfirm

# Step 2: Check for existing packages to avoid unnecessary installs
echo "🔍 Checking for existing packages..."
pacman -Q base-devel git curl terminus-font nerd-fonts-fira-code > /dev/null 2>&1 && {
    echo "⚠️ Some packages already installed, skipping installation."
    exit 0
}

# Step 3: Install base-devel, git, curl, and terminus-font (for virtual console)
echo "📦 Installing base-devel, git, curl, and terminus-font..."
echo "base-devel git curl terminus-font" > "$STATE_DIR/installed_packages"
pacman -S --noconfirm base-devel git curl terminus-font

# Step 4: Install paru (AUR helper) for Nerd Fonts
echo "🛠️ Installing paru for AUR package management..."
if ! command -v paru > /dev/null; then
    useradd -m -s /bin/bash paruuser
    echo "paruuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/paruuser
    cd /tmp
    git clone https://aur.archlinux.org/paru.git
    chown -R paruuser:paruuser paru
    cd paru
    su paruuser -c "makepkg -si --noconfirm"
    cd /tmp
    rm -rf paru
    touch "$STATE_DIR/paru_installed"
fi

# Step 5: Install FiraCode Nerd Font
echo "🖌️ Installing FiraCode Nerd Font..."
echo "nerd-fonts-fira-code" >> "$STATE_DIR/installed_packages"
su paruuser -c "paru -S --noconfirm nerd-fonts-fira-code"

# Step 6: Apply font to virtual console
echo "⚙️ Configuring Terminus font for virtual console (Nerd Fonts not supported in vconsole)..."
if [ -f /etc/vconsole.conf ]; then
    cp /etc/vconsole.conf "$STATE_DIR/vconsole.conf.bak"
fi
echo "FONT=ter-v16n" > /etc/vconsole.conf
mkfontdir /usr/share/fonts/terminus
fc-cache -fv

# Step 7: Configure FiraCode Nerd Font for GUI terminals (example: xfce4-terminal)
echo "⚙️ Configuring FiraCode Nerd Font for xfce4-terminal..."
mkdir -p ~/.config/xfce4/xfce4-terminal
if [ -f ~/.config/xfce4/xfce4-terminal/terminalrc ]; then
    cp ~/.config/xfce4/xfce4-terminal/terminalrc "$STATE_DIR/xfce4-terminal-config.bak"
fi
cat << EOF > ~/.config/xfce4/xfce4-terminal/terminalrc
[Configuration]
FontName=FiraCode Nerd Font 12
EOF

# Step 8: Verify installations
echo "✅ Verifying installed packages..."
for pkg in git curl terminus-font nerd-fonts-fira-code; do
    pacman -Q "$pkg" > /dev/null || {
        echo "❌ Verification failed for $pkg!"
        exit 1
    }
done

# Step 9: Clean up temporary user and state if successful
userdel -r paruuser || echo "⚠️ Failed to remove paruuser, manual cleanup may be needed."
rm -f /etc/sudoers.d/paruuser
rm -rf "$STATE_DIR"
echo "🎉 Step 1 complete: System updated, base packages, and FiraCode Nerd Font installed! 🚀"
echo "ℹ️ FiraCode Nerd Font applied to xfce4-terminal. For other GUI terminals (e.g., GNOME Terminal, Kitty), manually set 'FiraCode Nerd Font' in their preferences."
echo "ℹ️ Virtual console uses Terminus font (ter-v16n) as Nerd Fonts are not supported in vconsole."