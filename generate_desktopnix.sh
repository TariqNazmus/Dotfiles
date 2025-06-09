#!/bin/bash

# Exit on error, unset variables, or pipeline failure
set -euo pipefail

# Constant for main user
MAIN_USER="sadat"

# Check if running with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run with sudo! Run as: sudo bash generate-desktop-nix.sh"
    exit 1
fi

# Print a fun header 😎
echo "🚀 Generating desktop.nix with automated sha256 for $MAIN_USER 🚀"

# Temporary directory for fetching
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Function to fetch sha256 for a URL
fetch_sha256_url() {
    local url=$1
    sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-prefetch-url --type sha256 \"$url\"" 2>/dev/null
}

# Function to fetch sha256 for a Git commit
fetch_sha256_git() {
    local repo=$1
    local rev=$2
    sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && nix-prefetch-git --url \"$repo\" --rev \"$rev\" --quiet | grep sha256 | cut -d '\"' -f 4"
}

# Verify nix-prefetch-git is available
if ! sudo -u "$MAIN_USER" bash -c "source /home/$MAIN_USER/.nix-profile/etc/profile.d/nix.sh && command -v nix-prefetch-git" >/dev/null; then
    echo "❌ nix-prefetch-git not found! Ensure nix-prefetch-scripts is installed."
    exit 1
fi

# Fetch sha256 for zsh-5.9
ZSH_URL="https://sourceforge.net/projects/zsh/files/zsh/5.9/zsh-5.9.tar.xz"
ZSH_SHA256=$(fetch_sha256_url "$ZSH_URL")
if [ -z "$ZSH_SHA256" ]; then
    echo "❌ Failed to fetch sha256 for zsh-5.9!"
    exit 1
fi

# Fetch sha256 for oh-my-zsh (commit from Nixpkgs 25.05)
OHMYZSH_REPO="https://github.com/ohmyzsh/ohmyzsh"
OHMYZSH_REV="3ff8c7e"
OHMYZSH_SHA256=$(fetch_sha256_git "$OHMYZSH_REPO" "$OHMYZSH_REV")
if [ -z "$OHMYZSH_SHA256" ]; then
    echo "❌ Failed to fetch sha256 for oh-my-zsh commit $OHMYZSH_REV!"
    exit 1
fi

# Generate desktop.nix
cat << EOF > desktop.nix
{
  # Pin Nixpkgs to 25.05 for reproducibility
  nixpkgs ? import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/25.05.tar.gz";
    sha256 = "sha256-v/HdrU2OvqAtMA9DWFni9XzJHLdJ02z2S2AfJanvmkI=";
  }) {}
}:

let
  pkgs = nixpkgs;

  # Pin zsh to 5.9
  pinnedZsh = pkgs.zsh.overrideAttrs (old: {
    version = "5.9";
    src = pkgs.fetchurl {
      url = "$ZSH_URL";
      sha256 = "$ZSH_SHA256";
    };
  });

  # Pin oh-my-zsh to a specific commit
  pinnedOhMyZsh = pkgs.oh-my-zsh.overrideAttrs (old: {
    src = pkgs.fetchFromGitHub {
      owner = "ohmyzsh";
      repo = "ohmyzsh";
      rev = "$OHMYZSH_REV";
      sha256 = "$OHMYZSH_SHA256";
    };
  });
in
{
  environment = pkgs.buildEnv {
    name = "sadat-desktop-env";
    paths = with pkgs; [
      pinnedZsh
      pinnedOhMyZsh
    ];
  };
}
EOF

chown "$MAIN_USER:$MAIN_USER" desktop.nix
echo "🎉 desktop.nix generated with automated sha256 values! 🚀"