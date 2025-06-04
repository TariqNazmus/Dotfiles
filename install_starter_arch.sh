#!/usr/bin/env bash
set -e

USERNAME="sadat"
NIXPKGS_COMMIT="f9f18451e1e75a28744d8f8811e3c4b82bba0a9f"  # pinned to 2025-06
NIXPKGS="https://nixos.org/channels/nixpkgs-unstable/archive/${NIXPKGS_COMMIT}.tar.gz"

echo "[1/6] Installing Nix (multi-user mode)..."
if ! command -v nix >/dev/null; then
  curl -L https://nixos.org/nix/install | sh -s -- --daemon
fi

. /etc/profile.d/nix.sh

echo "[2/6] Enabling flakes and nix-command..."
sudo mkdir -p /etc/nix
echo "experimental-features = nix-command flakes" | sudo tee /etc/nix/nix.conf

echo "[3/6] Setting pinned nixpkgs registry..."
nix --extra-experimental-features 'nix-command flakes' registry pin nixpkgs "$NIXPKGS"

echo "[4/6] Installing Wayland desktop packages with pinned nixpkgs..."
nix profile install \
  "nixpkgs#hyprland" \
  "nixpkgs#waybar" \
  "nixpkgs#wofi" \
  "nixpkgs#kitty" \
  "nixpkgs#zsh"

echo "[5/6] Optional: Installing dev tools (neovim, git, python3, etc)..."
nix profile install \
  "nixpkgs#neovim" \
  "nixpkgs#git" \
  "nixpkgs#python3" \
  "nixpkgs#nodejs" \
  "nixpkgs#tmux" \
  "nixpkgs#clang-tools"

echo "[6/6] All done! Nix-based Wayland desktop setup is ready for user: $USERNAME"

echo
echo "📂 Next Steps:"
echo "1. Add Hyprland config to ~/.config/hypr/"
echo "2. Add this line to ~/.zprofile or ~/.zshrc:"
echo "   . /etc/profile.d/nix.sh"
echo "3. (Optional) Auto-launch Hyprland on TTY login:"
echo '   [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec Hyprland'