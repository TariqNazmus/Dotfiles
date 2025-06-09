#!/bin/bash

# Exit on error, unset variables, or pipeline failure
set -euo pipefail

# Constant for main user
MAIN_USER="sadat"

# Check if running with sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run with sudo! Run as: sudo bash setup-arch-step2-pacman.sh"
    exit 1
fi

# Print a fun header 😎
echo "🚀 Starting Arch Linux Setup for $MAIN_USER: Step 2 - Pinned Zsh and Fonts (Pacman/Paru) 🚀"

# Directory to store temporary state for rollback
STATE_DIR="/tmp/arch_setup_state_pacman"
mkdir -p "$STATE_DIR"

# Directory for custom PKGBUILDs
AUR_PKGS_DIR="/home/$MAIN_USER/.aur_pkgs"
mkdir -p "$AUR_PKGS_DIR"
chown "$MAIN_USER:$MAIN_USER" "$AUR_PKGS_DIR"

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

    if [ -f "$STATE_DIR/installed_packages" ]; then
        echo "🗑️ Removing installed packages..."
        mapfile -t pkgs < "$STATE_DIR/installed_packages"
        if [ ${#pkgs[@]} -gt 0 ]; then
            pacman -Rns --noconfirm "${pkgs[@]}" || echo "⚠️ Failed to remove some packages, manual cleanup may be needed."
        fi
    fi

    if [ -f "$STATE_DIR/paru_installed" ]; then
        echo "🗑️ Removing paru..."
        rm -rf "/home/$MAIN_USER/paru"
        pacman -Rns --noconfirm paru || echo "⚠️ Failed to remove paru, manual cleanup may be needed."
    fi

    if [ -f "$STATE_DIR/zshrc.bak" ]; then
        echo "🔄 Restoring original .zshrc..."
        mv "$STATE_DIR/zshrc.bak" "/home/$MAIN_USER/.zshrc" || echo "⚠️ Failed to restore .zshrc."
    fi

    if [ -f "$STATE_DIR/passwd.bak" ]; then
        echo "🔄 Restoring original /etc/passwd..."
        mv "$STATE_DIR/passwd.bak" /etc/passwd || echo "⚠️ Failed to restore /etc/passwd."
    fi

    if [ -f "$STATE_DIR/vconsole.conf.bak" ]; then
        echo "🔄 Restoring original vconsole.conf..."
        mv "$STATE_DIR/vconsole.conf.bak" /etc/vconsole.conf || echo "⚠️ Failed to restore vconsole.conf."
    fi

    if [ -f "$STATE_DIR/xfce4-terminal-config.bak" ]; then
        echo "🔄 Restoring original xfce4-terminal configuration..."
        mv "$STATE_DIR/xfce4-terminal-config.bak" "/home/$MAIN_USER/.config/xfce4/xfce4-terminal/terminalrc" || echo "⚠️ Failed to restore xfce4-terminal config."
    elif [ -f "/home/$MAIN_USER/.config/xfce4/xfce4-terminal/terminalrc" ]; then
        rm -f "/home/$MAIN_USER/.config/xfce4/xfce4-terminal/terminalrc"
    fi

    if [ -f "$STATE_DIR/pacman.conf.bak" ]; then
        echo "🔄 Restoring original pacman.conf..."
        mv "$STATE_DIR/pacman.conf.bak" /etc/pacman.conf || echo "⚠️ Failed to restore pacman.conf."
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

# Step 2: Update Arch system
echo "🔄 Updating Arch system..."
progress_bar 10 "Updating system..."
pacman -Syu --noconfirm

# Step 3: Install base packages
echo "📦 Installing base packages..."
progress_bar 10 "Installing base packages..."
if pacman -Q base-devel git curl terminus-font xorg-mkfontscale > /dev/null 2>&1; then
    echo "⚠️ Some base packages already installed."
else
    echo "base-devel git curl terminus-font xorg-mkfontscale" > "$STATE_DIR/installed_packages"
    pacman -S --noconfirm base-devel git curl terminus-font xorg-mkfontscale
fi

# Step 4: Install paru (AUR helper)
echo "🛠️ Installing paru for AUR package management..."
if ! command -v paru > /dev/null; then
    progress_bar 10 "Installing paru..."
    cd "$USER_HOME"
    sudo -u "$MAIN_USER" git clone https://aur.archlinux.org/paru.git
    cd paru
    sudo -u "$MAIN_USER" makepkg -si --noconfirm
    cd "$USER_HOME"
    rm -rf paru
    touch "$STATE_DIR/paru_installed"
fi

# Step 5: Install JetBrains Mono Nerd Font
echo "🖌️ Installing JetBrains Mono Nerd Font..."
if ! pacman -Q ttf-jetbrains-mono-nerd > /dev/null 2>&1; then
    progress_bar 10 "Installing JetBrains Mono Nerd Font..."
    echo "ttf-jetbrains-mono-nerd" >> "$STATE_DIR/installed_packages"
    sudo -u "$MAIN_USER" paru -S --noconfirm ttf-jetbrains-mono-nerd
fi

# Step 6: Create custom PKGBUILD for zsh-5.9
echo "🛠️ Creating custom PKGBUILD for zsh-5.9..."
progress_bar 5 "Creating zsh PKGBUILD..."
mkdir -p "$AUR_PKGS_DIR/zsh"
cat << EOF > "$AUR_PKGS_DIR/zsh/PKGBUILD"
pkgname=zsh
pkgver=5.9
pkgrel=1
pkgdesc="A very advanced and programmable command interpreter (shell)"
arch=('x86_64')
url="https://www.zsh.org/"
license=('custom')
depends=('pcre' 'libcap' 'gdbm')
source=("https://sourceforge.net/projects/zsh/files/zsh/\$pkgver/zsh-\$pkgver.tar.xz")
sha256sums=('9b8d40a5b255d1efced7a5937e9f1a3f36f0ccad37d93f48c22b5b5a5c092a91')

build() {
  cd "\$srcdir/zsh-\$pkgver"
  ./configure --prefix=/usr \\
              --enable-pcre \\
              --enable-cap \\
              --enable-gdbm \\
              --enable-multibyte \\
              --enable-zsh-secure-free
  make
}

package() {
  cd "\$srcdir/zsh-\$pkgver"
  make DESTDIR="\$pkgdir" install
  install -Dm644 LICENCE "\$pkgdir/usr/share/licenses/\$pkgname/LICENCE"
}
EOF
chown -R "$MAIN_USER:$MAIN_USER" "$AUR_PKGS_DIR/zsh"

# Step 7: Install zsh-5.9 from custom PKGBUILD
echo "🛠️ Installing zsh-5.9 from custom PKGBUILD..."
if ! pacman -Q zsh > /dev/null 2>&1 || ! /usr/bin/zsh --version | grep -q "5.9"; then
    progress_bar 15 "Installing zsh-5.9..."
    cd "$AUR_PKGS_DIR/zsh"
    sudo -u "$MAIN_USER" makepkg -si --noconfirm
    echo "zsh" >> "$STATE_DIR/installed_packages"
fi
ZSH_PATH="/usr/bin/zsh"

# Step 8: Create custom PKGBUILD for oh-my-zsh
echo "🛠️ Creating custom PKGBUILD for oh-my-zsh (pinned commit)..."
progress_bar 5 "Creating oh-my-zsh PKGBUILD..."
mkdir -p "$AUR_PKGS_DIR/oh-my-zsh"
cat << EOF > "$AUR_PKGS_DIR/oh-my-zsh/PKGBUILD"
pkgname=oh-my-zsh-git
pkgver=r7302.a3f37b8
pkgrel=1
pkgdesc="A community-driven framework for managing your zsh configuration"
arch=('any')
url="https://github.com/ohmyzsh/ohmyzsh"
license=('MIT')
depends=('zsh')
makedepends=('git')
source=("git+https://github.com/ohmyzsh/ohmyzsh.git#commit=3ff8c7e")
sha256sums=('SKIP')
options=('!strip')

package() {
  mkdir -p "\$pkgdir/usr/share/oh-my-zsh"
  cp -r "\$srcdir/ohmyzsh/"* "\$pkgdir/usr/share/oh-my-zsh/"
  install -Dm644 "\$srcdir/ohmyzsh/LICENSE.txt" "\$pkgdir/usr/share/licenses/\$pkgname/LICENSE"
}
EOF
chown -R "$MAIN_USER:$MAIN_USER" "$AUR_PKGS_DIR/oh-my-zsh"

# Step 9: Install oh-my-zsh from custom PKGBUILD
echo "🛠️ Installing oh-my-zsh from custom PKGBUILD..."
if ! pacman -Q oh-my-zsh-git > /dev/null 2>&1; then
    progress_bar 10 "Installing oh-my-zsh..."
    cd "$AUR_PKGS_DIR/oh-my-zsh"
    sudo -u "$MAIN_USER" makepkg -si --noconfirm
    echo "oh-my-zsh-git" >> "$STATE_DIR/installed_packages"
fi

# Step 10: Prevent package updates
echo "🔒 Preventing updates for zsh and oh-my-zsh..."
progress_bar 5 "Configuring pacman..."
cp /etc/pacman.conf "$STATE_DIR/pacman.conf.bak"
if ! grep -q "IgnorePkg = zsh oh-my-zsh-git" /etc/pacman.conf; then
    echo "IgnorePkg = zsh oh-my-zsh-git" >> /etc/pacman.conf
fi

# Step 11: Apply font to virtual console
echo "⚙️ Configuring Terminus font for virtual console (Nerd Fonts not supported in vconsole)..."
progress_bar 5 "Configuring virtual console font..."
if [ -f /etc/vconsole.conf ]; then
    cp /etc/vconsole.conf "$STATE_DIR/vconsole.conf.bak"
fi
echo "FONT=ter-v16n" > /etc/vconsole.conf
mkfontscale /usr/share/fonts/terminus
fc-cache -fv

# Step 12: Configure JetBrains Mono Nerd Font for xfce4-terminal
echo "⚙️ Configuring JetBrains Mono Nerd Font for xfce4-terminal..."
progress_bar 5 "Configuring GUI terminal font..."
mkdir -p "$USER_HOME/.config/xfce4/xfce4-terminal"
chown "$MAIN_USER:$MAIN_USER" "$USER_HOME/.config/xfce4" "$USER_HOME/.config/xfce4/xfce4-terminal"
if [ -f "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc" ]; then
    cp "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc" "$STATE_DIR/xfce4-terminal-config.bak"
fi
cat << EOF > "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc"
[Configuration]
FontName=JetBrainsMono Nerd Font Bold 14
EOF
chown "$MAIN_USER:$MAIN_USER" "$USER_HOME/.config/xfce4/xfce4-terminal/terminalrc"

# Step 13: Set zsh as default shell
echo "⚙️ Setting zsh as default shell for $MAIN_USER..."
progress_bar 5 "Configuring zsh..."
if [ ! -f "$ZSH_PATH" ]; then
    echo "❌ zsh not found at $ZSH_PATH!"
    exit 1
fi
cp /etc/passwd "$STATE_DIR/passwd.bak"
chsh -s "$ZSH_PATH" "$MAIN_USER"

# Step 14: Configure .zshrc
echo "⚙️ Configuring .zshrc for $MAIN_USER..."
progress_bar 5 "Configuring .zshrc..."
if [ -f "/home/$MAIN_USER/.zshrc" ]; then
    cp "/home/$MAIN_USER/.zshrc" "$STATE_DIR/zshrc.bak"
fi
cat << EOF > "/home/$MAIN_USER/.zshrc"
# Oh My Zsh configuration
export ZSH="/usr/share/oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git)
source \$ZSH/oh-my-zsh.sh

# Basic settings
export PATH=\$HOME/bin:/usr/local/bin:\$PATH
alias ls='ls --color=auto'
alias ll='ls -l'
EOF
chown "$MAIN_USER:$MAIN_USER" "/home/$MAIN_USER/.zshrc"

# Step 15: Verify configuration
echo "✅ Verifying configuration..."
progress_bar 5 "Verifying configuration..."
if ! "$ZSH_PATH" --version >/dev/tty | grep -q "5.9"; then
  echo "❌ zsh version verification failed! Expected 5.9."
  exit 1
fi
if ! grep -q "$ZSH_PATH" /etc/passwd; then
    echo "❌ zsh not set as default shell!"
    exit 1
fi
if [ ! -d "/usr/share/oh-my-zsh" ]; then
    echo "❌ oh-my-zsh not installed correctly!"
    exit 1
fi

# Step 16: Clean up state if successful
rm -rf "$STATE_DIR"
echo "🎉 Step 2 complete: Zsh 5.9 and oh-my-zsh (pinned) with fonts installed and configured! 🚀"
echo "ℹ️ JetBrains Mono Nerd Font (Bold, size 14) applied to xfce4-terminal. For other GUI terminals (e.g., GNOME Terminal, Kitty), manually set 'JetBrainsMono Nerd Font Bold' in their preferences."
echo "ℹ️ Virtual console uses Terminus font (ter-v16n) as Nerd Fonts are not supported in vconsole."
echo "ℹ️ zsh is now the default shell for $MAIN_USER. Log out and log in to use it."
echo "ℹ️ Custom PKGBUILDs stored in $AUR_PKGS_DIR for reproducibility."
echo "ℹ️ zsh and oh-my-zsh updates are prevented via /etc/pacman.conf. Remove 'IgnorePkg' to allow updates."