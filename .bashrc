[[ $- == *i* ]] && source /usr/share/blesh/ble.sh --noattach

#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

export PATH=$PATH:/home/brett/.spicetify
export PATH="$HOME/.local/bin:$PATH"
[[ -f ~/.secrets ]] && source ~/.secrets

if command -v fastfetch &>/dev/null; then
    fastfetch
fi

# fzf keybindings and completion
eval "$(fzf --bash)" 2>/dev/null

# bash-completion
[[ -f /usr/share/bash-completion/bash_completion ]] && source /usr/share/bash-completion/bash_completion

# ble.sh attach (must be last)
[[ ${BLE_VERSION-} ]] && ble-attach
alias dotfiles='/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME'
