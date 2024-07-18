# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

eval "$(oh-my-posh init zsh --config ~/.oh-my-posh/themes/kushal.omp.json)"
source ~/.zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.plugin.zsh


# ---- Eza (better ls) -----

alias ls="eza --icons=always"
