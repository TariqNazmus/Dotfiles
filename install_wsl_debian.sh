#!/bin/bash

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

update_and_upgrade(){
    echo "Updating package list..."
    sudo apt update

    echo "Upgrading package list..."
    sudo apt upgrade -y
}

# install Zsh
install_zsh() {
    if ! command_exists zsh; then
        echo "Installing Zsh..."
        sudo apt install -y zsh
    else
        echo "zsh is already installed."
    fi
}

# Install Oh My Posh
install_oh_my_posh() {
    if ! command_exists oh-my-posh; then
        echo "Installing Oh My Posh..."
        sudo apt install -y wget
        wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O oh-my-posh
        sudo chmod +x oh-my-posh
        sudo mv oh-my-posh /usr/local/bin/oh-my-posh
    else
        echo "Oh My Posh is already installed."
    fi
}

# Download and set the theme
set_oh_my_posh_theme() {
    if [ ! -f "$HOME/.poshthemes/themes" ]; then
        echo "Downloading themes for Oh My Posh..."
        git clone --depth=1 https://github.com/JanDeDobbeleer/oh-my-posh.git ~/.oh-my-posh/temp
        mkdir -p ~/.oh-my-posh/themes
        mkdir -p ~/.cache
        echo "Downloading the kushal theme for Oh My Posh..."
        mv ~/.oh-my-posh/temp/themes/* ~/.oh-my-posh/themes
        sudo rm -rf ~/.oh-my-posh/temp
    fi

    echo "Setting the theme in .zshrc..."
    if ! grep -q "oh-my-posh" ~/.zshrc; then
        echo 'eval "$(oh-my-posh init zsh --config ~/.oh-my-posh/themes/blue-owl.omp.json)"' >> ~/.zshrc
        # echo 'eval "$(oh-my-posh init zsh --config ~/.oh-my-posh/themes/kushal.omp.json)"' >> ~/.zshrc
    fi
}

# Clone, compile, and install the latest stable Neovim
install_neovim() {
    if ! command_exists nvim; then
        echo "Installing dependencies for Neovim..."
        sudo apt install -y  ninja-build gettext cmake unzip curl build-essential

        echo "Cloning the Neovim repository..."
        git clone  https://github.com/neovim/neovim.git
        cd neovim
        git checkout stable

        echo "Building Neovim..."
        make CMAKE_BUILD_TYPE=Release

        echo "Installing Neovim..."
        sudo make install

        echo "Cleaning up..."
        cd ..
        rm -rf neovim
    else
        echo "Neovim is already installed."
    fi
}

# Install Zsh plugins: zsh-autosuggestions and zsh-syntax-highlighting
install_zsh_plugins() {
    local zsh_dir="${ZSH:-$HOME/.zsh}"

    if [ ! -d "$zsh_dir/plugins/zsh-autosuggestions" ]; then
        echo "Installing zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git $zsh_dir/plugins/zsh-autosuggestions
    else
        echo "zsh-autosuggestions is already installed."
    fi

    if [ ! -d "$zsh_dir/plugins/zsh-syntax-highlighting" ]; then
        echo "Installing zsh-syntax-highlighting..."
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git $zsh_dir/plugins/zsh-syntax-highlighting
    else
        echo "zsh-syntax-highlighting is already installed."
    fi

}

# Install eza
install_eza() {
    if ! command_exists eza; then
        echo "Installing wget..."
        sudo apt install -y wget

        echo "Installing eza..."
        wget -c https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz -O - | tar xz
        sudo chmod +x eza
        sudo chown root:root eza
        sudo mv eza /usr/local/bin/eza
    else
        echo "eza is already installed."
    fi
}

# Install basic stuff like git 
install_essentials() {
    if ! command_exists git; then
        echo "Installing git..."
        sudo apt install -y git

    else
        echo "git is already installed."
    fi
}

# Clone the Dotfiles repository and update .zshrc
clone_dotfiles() {
    if [ ! -d "$HOME/.dotfiles" ]; then
        echo "Cloning the Dotfiles repository..."
        git clone https://github.com/TariqNazmus/Dotfiles.git $HOME/.dotfiles
        echo "Copying .zshrc from Dotfiles..."
        cp $HOME/.dotfiles/.zshrc $HOME/.zshrc
    else
        echo "Dotfiles repository is already cloned."
    fi
}



update_and_upgrade

# Install things one always need
install_essentials

install_zsh

# Change the default shell to Zsh
echo "Changing default shell to Zsh..."
chsh -s $(which zsh)

# Install Oh My Posh
install_oh_my_posh

# Set the Oh My Posh theme
set_oh_my_posh_theme

# Install Neovim
install_neovim

# Install Zsh plugins
install_zsh_plugins

# Install eza
install_eza


# Clone Dotfiles repository and update .zshrc
clone_dotfiles

echo "Installation complete. Please log out and log back in to start using Zsh with Oh My Posh and the specified theme."

