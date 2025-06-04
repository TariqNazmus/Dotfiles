#!/usr/bin/env bash
set -e

USERNAME="sata"
NIXPKGS_COMMIT="f9f18451e1e75a28744d8f8811e3c4b82bba0a9f"
NIXPKGS="https://nixos.org/channels/nixpkgs-unstable/archive/${NIXPKGS_COMMIT}.tar.gz"

echo "[1/5] Installing Nix (multi-user)..."
if ! command -v nix >/dev/null; then
  curl -L https://nixos.org/nix/install | sh -s -- --daemon
fi

. /etc/profile.d/nix.sh

echo "[2/5] Enabling nix-command and flakes..."
sudo mkdir -p /etc/nix
echo "experimental-features = nix-command flakes" | sudo tee /etc/nix/nix.conf

echo "[3/5] Setting pinned nixpkgs..."
nix --extra-experimental-features 'nix-command flakes' registry pin nixpkgs "$NIXPKGS"

echo "[4/5] Installing core graphical apps using pinned nixpkgs..."
nix profile install "nixpkgs#hyprland" \
                    "nixpkgs#waybar" \
                    "nixpkgs#wofi" \
                    "nixpkgs#kitty" \
                    "nixpkgs#zsh"

echo "[5/5] Done. You can now run Hyprland from TTY or set up your Hyprland config at ~/.config/hypr"

echo
echo "Tip: Add this to your .zprofile or .zshrc:"
echo "  . /etc/profile.d/nix.sh"