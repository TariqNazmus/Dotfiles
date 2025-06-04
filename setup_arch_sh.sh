#!/usr/bin/env bash
set -euo pipefail

# ✅ Basic info
USERNAME="sadat"
NIXPKGS_COMMIT="9c09d5e27cd07348e2177fcca51badb0446f1a43"
NIXPKGS="github:NixOS/nixpkgs/${NIXPKGS_COMMIT}"

# ✅ Install Nix if not already installed
echo "[1/6] Installing Nix (multi-user mode)..."
if ! command -v nix >/dev/null; then
  curl -L https://nixos.org/nix/install | sh -s -- --daemon
fi
# ✅ Source nix profile for current session
echo "[2/6] Sourcing nix profile..."
. /etc/profile.d/nix.sh

# ✅ Ensure nix.conf has flakes + command support
echo "[3/6] Enabling flakes and nix-command..."
sudo mkdir -p /etc/nix
echo "experimental-features = nix-command flakes" | sudo tee /etc/nix/nix.conf >/dev/null

# ✅ Pin nixpkgs registry
echo "[4/6] Pinning nixpkgs to commit $NIXPKGS_COMMIT..."
nix --extra-experimental-features 'nix-command flakes' registry pin nixpkgs "$NIXPKGS"

# ✅ Install packages using pinned registry
echo "[5/6] Installing desktop environment apps..."
nix profile install \
  "nixpkgs#hyprland" \
  "nixpkgs#wayland" \
  "nixpkgs#xdg-desktop-portal" \
  "nixpkgs#xdg-desktop-portal-wlr" \
  "nixpkgs#wl-clipboard" \
  "nixpkgs#qt5.qtwayland" \
  "nixpkgs#qt6.qtwayland" \
  "nixpkgs#glib" \
  "nixpkgs#dbus" \
  "nixpkgs#waybar" \
  "nixpkgs#wofi" \
  "nixpkgs#kitty" \
  "nixpkgs#zsh" \
  "nixpkgs#clang-tools" \

# echo "[6/6] Installing development tools..."
# nix profile install \
#   "nixpkgs#neovim" \
#   "nixpkgs#git" \
#   "nixpkgs#python3" \
#   "nixpkgs#nodejs" \
#   "nixpkgs#tmux" \
#   "nixpkgs#clang-tools"

echo
echo "✅ Done! Nix-based Wayland dev environment is ready for user: $USERNAME"
echo
echo "👉 Next steps:"
echo "1. Add Hyprland config in: ~/.config/hypr/"
echo "2. Add to ~/.zprofile or ~/.zshrc:"
echo '   . /etc/profile.d/nix.sh'
echo "3. To auto-launch Hyprland on TTY1, add to ~/.zprofile:"
echo '   [[ -z $DISPLAY && $XDG_VTNR -eq 1 ]] && exec Hyprland'