reloadbash() {
    
    # Oh My zsh Configuration:
    export ZSH="$HOME/.oh-my-zsh"
    export ZSH_THEME=gruvbox
    
    plugins=(
        zsh-syntax-highlighting
        zsh-navigation-tools
        zsh-interactive-cd
        zsh-autosuggestions
    )
    
    source $ZSH/oh-my-zsh.sh
    export PATH=$PATH:$HOME/.local/bin:$HOME/.cargo/bin

    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

    [[ "$TERM" == "xterm-kitty" ]] && alias ssh="TERM=xterm-256color ssh" 
        
    # Enable auto expansion of parameters and variables:
    zstyle ':completion:*' completer _expand _complete
    autoload -Uz compinit
    compinit
    
    SAVEHIST=10000 # Save most-recent 10000 lines
    HISTFILE=~/.zsh_history

    if [ -d ~/.scripts ]; then
        if [ -n "$(ls -A ~/.scripts)" ]; then
            for script in ~/.scripts/*; do
                source $script
            done
        fi
    fi

    if [ -d ~/.scripts/non-commit ]; then
        if [ -n "$(ls -A ~/.scripts/non-commit)" ]; then 
            for script in ~/.scripts/non-commit/*; do
                source $script
            done
        fi
    fi
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/ssh-agent.socket"
    
    # SSH_PASSPHRASE=$(cat ~/.scripts/non-commit/passfile)
    
    { sleep .1; echo $SSH_PASSPHRASE; } | script -q /dev/null -c 'ssh-add ~/.ssh/keys/github-elesoft-bjss' &> /dev/null
    
    if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    fi
    
    export NIX_PATH=$HOME/.nix-defexpr/channels:/nix/var/nix/profiles/per-user/root/channels${NIX_PATH:+:$NIX_PATH}
    
}

reloadbash

if [ -e /home/mpendlebury/.nix-profile/etc/profile.d/nix.sh ]; then . /home/mpendlebury/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
alias claude="/home/mpendlebury/.claude/local/claude"
export PATH="$PATH:/home/mpendlebury/Documents/repos/AI/ai-assistant-v2"
export PATH="$PATH:/home/mpendlebury/Documents/repos/AI/ai-assistant-v2"
export PATH="$PATH:/home/mpendlebury/Documents/repos/AI/ai-assistant-v2"
