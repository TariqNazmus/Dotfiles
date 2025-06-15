#!/bin/bash

# Exit on error
set -e

# Update system and install base packages
sudo pacman -Syu --noconfirm
sudo pacman -S --noconfirm base-devel git

# Install yay (AUR helper) as user sadat
if ! command -v yay &> /dev/null; then
    git clone https://aur.archlinux.org/yay.git ~/yay
    cd ~/yay
    makepkg -si --noconfirm
    cd ~
    rm -rf ~/yay
fi

# Install Hyprland and dependencies
sudo pacman -S --noconfirm hyprland xdg-desktop-portal-hyprland wl-clipboard

# Install Wezterm, zsh, JetBrains Mono Nerd Font, and developer tools
sudo pacman -S --noconfirm wezterm zsh ttf-jetbrains-mono-nerd networkmanager
yay -S --noconfirm neovim gcc

# Enable services
sudo systemctl enable NetworkManager

# Configure Hyprland
mkdir -p ~/.config/hypr
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

# Configure Wezterm with JetBrains Mono Nerd Font Bold, size 14
cat << 'EOF' > ~/.wezterm.lua
local wezterm = require 'wezterm'
return {
    font = wezterm.font('JetBrainsMono Nerd Font', { weight = 'Bold' }),
    font_size = 14,
    color_scheme = 'Dracula',
    default_prog = { '/usr/bin/zsh' },
}
EOF

# Set up zsh with Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
cat << 'EOF' > ~/.zshrc
ZSH_THEME="agnoster"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh
EOF

# Set up dotfiles repository
mkdir -p ~/dotfiles
cp -r ~/.config/hypr ~/.wezterm.lua ~/.zshrc ~/dotfiles
cd ~/dotfiles
git init
git add .
git commit -m "Initial dotfiles"
# Uncomment and set your repo URL after creating it
# git remote add origin <your-repo-url>
# git push -u origin main

# Auto-start Hyprland on tty1
echo 'if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then exec Hyprland; fi' >> ~/.zprofile

echo "Setup complete! Reboot and log in to start Hyprland."
echo "To push dotfiles, set up a remote Git repo and run: cd ~/dotfiles && git remote add origin <url> && git push -u origin main"