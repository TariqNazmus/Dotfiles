#!/bin/bash

# Exit on error, unset variables, or pipeline failure
set -euo pipefail

# Constant for main user
MAIN_USER="sadat"

# Check if running with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run with sudo! Run as: sudo bash setup-arch-step3-desktop.sh"
    exit 1
fi

# Print a fun header 😎
echo "🚀 Starting Arch Linux Setup for $MAIN_USER: Step 3 - Desktop Environment (Nix) 🚀"

# Directory to store temporary state for rollback
STATE_DIR="/tmp/arch_setup_state_desktop"
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

    if [ -f "$STATE_DIR/zshrc.bak" ]; then
        echo "🔄 Restoring original .zshrc..."
        mv "$STATE_DIR/zshrc.bak" "/home/$MAIN_USER/.zshrc" || echo "⚠️ Failed to restore .zshrc."
    fi

    if [ -f "$STATE_DIR/passwd.bak" ]; then
        echo "🔄 Restoring original /etc/passwd..."
        mv "$STATE_DIR/passwd.bak" /etc/passwd || echo "⚠️ Failed to restore /etc/passwd."
    fi

    if [ -f "$STATE_DIR/nix_profile_installed" ]; then
        echo "🗑️ Removing Nix profile..."
        sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-env -e sadat-desktop-env" || echo "⚠️ Failed to remove Nix profile."
    fi

    if [ -f "$STATE_DIR/nix_prefetch_scripts_installed" ]; then
        echo "🗑️ Removing nix-prefetch-scripts..."
        sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-env -e nix-prefetch-scripts" || echo "⚠️ Failed to remove nix-prefetch-scripts."
    fi

    if [ -f "$STATE_DIR/desktop_nix.bak" ]; then
        echo "🔄 Restoring original desktop.nix..."
        mv "$STATE_DIR/desktop_nix.bak" desktop.nix || echo "⚠️ Failed to restore desktop.nix."
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

# Step 2: Verify Nix is installed
echo "🔍 Verifying Nix installation..."
progress_bar 2 "Checking Nix..."
if [ ! -f "/home/$MAIN_USER/.nix-profile/bin/nix" ]; then
    echo "❌ Nix is not installed! Run setup-arch-step2-nix.sh first."
    exit 1
fi
source "/home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh"

# Step 3: Install nix-prefetch-scripts
echo "🛠️ Installing nix-prefetch-scripts for sha256 fetching..."
progress_bar 5 "Installing nix-prefetch-scripts..."
if ! sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && command -v nix-prefetch-git" >/dev/null; then
    sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-env -iA nixpkgs.nix-prefetch-scripts"
    touch "$STATE_DIR/nix_prefetch_scripts_installed"
fi

# Step 4: Generate desktop.nix with sha256 values
echo "🛠️ Generating desktop.nix with automated sha256..."
progress_bar 5 "Generating desktop.nix..."
if [ -f "desktop.nix" ]; then
    cp desktop.nix "$STATE_DIR/desktop_nix.bak"
fi
if ! sudo bash generate-desktop-nix.sh; then
    echo "❌ Failed to generate desktop.nix!"
    exit 1
fi

# Step 5: Install desktop environment from desktop.nix
echo "🛠️ Installing desktop environment from desktop.nix..."
progress_bar 10 "Installing desktop environment..."
sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-env -f desktop.nix -iA environment"
touch "$STATE_DIR/nix_profile_installed"

# Step 6: Set zsh as default shell
echo "⚙️ Setting zsh as default shell for $MAIN_USER..."
progress_bar 5 "Configuring zsh..."
ZSH_PATH="/home/$MAIN_USER/.nix-profile/bin/zsh"
if [ ! -f "$ZSH_PATH" ]; then
    echo "❌ zsh not found at $ZSH_PATH!"
    exit 1
fi
cp /etc/passwd "$STATE_DIR/passwd.bak"
chsh -s "$ZSH_PATH" "$MAIN_USER"

# Step 7: Configure .zshrc
echo "⚙️ Configuring .zshrc for $MAIN_USER..."
progress_bar 5 "Configuring .zshrc..."
if [ -f "/home/$MAIN_USER/.zshrc" ]; then
    cp "/home/$MAIN_USER/.zshrc" "$STATE_DIR/zshrc.bak"
fi
cat << EOF > "/home/$MAIN_USER/.zshrc"
# Source Nix environment
if [ -f ~/.nix-profile/etc/profile.d/nix.sh ]; then
    source ~/.nix-profile/etc/profile.d/nix.sh
fi

# Oh My Zsh configuration
export ZSH="/home/$MAIN_USER/.nix-profile/share/oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source \$ZSH/oh-my-zsh.sh

# Basic settings
export PATH=\$HOME/.nix-profile/bin:\$PATH
alias ls='ls --color=auto'
alias ll='ls -l'
EOF
chown "$MAIN_USER:$MAIN_USER" "/home/$MAIN_USER/.zshrc"

# Step 8: Verify configuration
echo "✅ Verifying configuration..."
progress_bar 5 "Verifying configuration..."
if ! sudo -u "$MAIN_USER" "$ZSH_PATH" --version | grep -q "5.9"; then
    echo "❌ zsh version verification failed! Expected 5.9."
    exit 1
fi
if ! grep -q "$ZSH_PATH" /etc/passwd; then
    echo "❌ zsh not set as default shell!"
    exit 1
fi

# Step 9: Clean up state if successful
rm -rf "$STATE_DIR"
echo "🎉 Step 3 complete: Desktop environment with pinned zsh (5.9) configured! 🚀"
echo "ℹ️ zsh is now the default shell for $MAIN_USER. Log out and log in to use it."
echo "ℹ️ Edit desktop.nix to add more packages (e.g., vscode, firefox) with specific versions and rerun this script."