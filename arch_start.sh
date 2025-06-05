#!/bin/bash

# Exit on error, unset variables, or pipeline failure
set -euo pipefail

# Print a fun header 😎
echo "🚀 Starting Arch Linux Setup: Step 1 - System Update & Base Packages 🚀"

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
pacman -Q base-devel git curl noto-fonts > /dev/null 2>&1 && {
    echo "⚠️ Some packages already installed, skipping installation."
    exit 0
}

# Step 3: Install base-devel, git, curl, and noto-fonts
echo "📦 Installing base-devel, git, curl, and noto-fonts..."
# Store list of packages to install
echo "base-devel git curl noto-fonts" > "$STATE_DIR/installed_packages"
pacman -S --noconfirm base-devel git curl noto-fonts

# Step 4: Verify installations
echo "✅ Verifying installed packages..."
for pkg in git curl noto-fonts; do
    pacman -Q "$pkg" > /dev/null || {
        echo "❌ Verification failed for $pkg!"
        exit 1
    }
done

# Step 5: Clean up state if successful
rm -rf "$STATE_DIR"
echo "🎉 Step 1 complete: System updated, base packages, and Noto Sans font installed! 🚀"