#!/bin/bash

# Exit on error
set -e

# Update system and install base packages
echo "Updating system and installing base packages..."
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm base-devel git

# Install yay (AUR helper)
if ! command -v yay &> /dev/null; then
    echo "Installing yay..."
    git clone https://aur.archlinux.org/yay.git ~/yay
    cd ~/yay
    makepkg -si --noconfirm
    cd ~
    rm -rf ~/yay
fi

# Install Hyprland and dependencies
echo "Installing Hyprland and dependencies..."
sudo pacman -S --noconfirm hyprland xdg-desktop-portal-hyprland wl-clipboard

# Install Wezterm, zsh, font, and developer tools
echo "Installing Wezterm, zsh, font, and tools..."
sudo pacman -S --noconfirm wezterm zsh ttf-jetbrains-mono-nerd networkmanager
yay -S --noconfirm neovim gcc

# Enable NetworkManager
echo "Enabling NetworkManager..."
sudo systemctl enable NetworkManager

# Create configuration directories and files
echo "Creating configuration files..."
mkdir -p ~/.config/hypr

# Hyprland config
cat << 'EOF' > ~/.config/hypr/hyprland.conf
monitor=,preferred,auto,1
exec-once=wezterm
input {
    kb_layout=us
    follow_mouse=1
}
general {
    gaps_in=5
    gaps_out=10
    border_size=2
}
bind=SUPER,Return,exec,wezterm
bind=SUPER,Q,exit
EOF

# Wezterm config
cat << 'EOF' > ~/.wezterm.lua
local wezterm = require 'wezterm'
return {
    font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Bold' }),
    font_size = 14,
    color_scheme = 'Dracula',
    default_prog = { '/usr/bin/zsh' },
}
EOF

# zsh config with Oh My Zsh
echo "Setting up zsh with Oh My Zsh..."
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
cat << 'EOF' > ~/.zshrc
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh
EOF

# Auto-start Hyprland on tty1
echo "Setting up Hyprland auto-start..."
echo 'if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then exec Hyprland; fi' >> ~/.zprofile

echo "Setup complete! Reboot to start Hyprland."