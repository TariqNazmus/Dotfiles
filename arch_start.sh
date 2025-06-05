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

    # Remove yay if installed
    if [ -f "$STATE_DIR/yay_installed" ]; then
        echo "🗑️ Removing yay..."
        rm -rf /tmp/yay
        userdel -r yayuser || echo "⚠️ Failed to remove yayuser, manual cleanup may be needed."
    fi

    # Restore original vconsole.conf if backed up
    if [ -f "$STATE_DIR/vconsole.conf.bak" ]; then
        echo "🔄 Restoring original vconsole.conf..."
        mv "$STATE_DIR/vconsole.conf.bak" /etc/vconsole.conf || echo "⚠️ Failed to restore vconsole.conf."
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
pacman -Q base-devel git curl nerd-fonts-fira-code > /dev/null 2>&1 && {
    echo "⚠️ Some packages already installed, skipping installation."
    exit 0
}

# Step 3: Install base-devel, git, curl
echo "📦 Installing base-devel, git, curl..."
echo "base-devel git curl" > "$STATE_DIR/installed_packages"
pacman -S --noconfirm base-devel git curl

# Step 4: Install yay (AUR helper) for Nerd Fonts
echo "🛠️ Installing yay for AUR package management..."
if ! command -v yay > /dev/null; then
    useradd -m -s /bin/bash yayuser
    echo "yayuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/yayuser
    cd /tmp
    git clone https://aur.archlinux.org/yay.git
    chown -R yayuser:yayuser yay
    cd yay
    su yayuser -c "makepkg -si --noconfirm"
    cd /tmp
    rm -rf yay
    userdel -r yayuser
    rm -f /etc/sudoers.d/yayuser
    touch "$STATE_DIR/yay_installed"
fi

# Step 5: Install FiraCode Nerd Font
echo "🖌️ Installing FiraCode Nerd Font..."
echo "nerd-fonts-fira-code" >> "$STATE_DIR/installed_packages"
su yayuser -c "yay -S --noconfirm nerd-fonts-fira-code"

# Step 6: Apply FiraCode Nerd Font to virtual console
echo "⚙️ Configuring FiraCode Nerd Font for virtual console..."
if [ -f /etc/vconsole.conf ]; then
    cp /etc/vconsole.conf "$STATE_DIR/vconsole.conf.bak"
fi
echo "FONT=firacode" > /etc/vconsole.conf
mkfontdir /usr/share/fonts/TTF
fc-cache -fv

# Step 7: Verify installations
echo "✅ Verifying installed packages..."
for pkg in git curl nerd-fonts-fira-code; do
    pacman -Q "$pkg" > /dev/null || {
        echo "❌ Verification failed for $pkg!"
        exit 1
    }
done

# Step 8: Clean up state if successful
rm -rf "$STATE_DIR"
echo "🎉 Step 1 complete: System updated, base packages, and FiraCode Nerd Font installed! 🚀"
echo "ℹ️ For GUI terminals (e.g., GNOME Terminal, Xfce Terminal), manually set 'FiraCode Nerd Font' in terminal preferences."