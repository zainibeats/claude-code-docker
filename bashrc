## contagent interactive shell defaults.
## Copied to /home/agent/.bashrc on first start; edit it there to customise
## (the home volume persists, so changes survive container restarts).

case $- in
    *i*) ;;
      *) return ;;
esac

## History lives on the persistent home volume, so it survives restarts the way
## host shell history does.
HISTCONTROL=ignoreboth
HISTSIZE=100000
HISTFILESIZE=200000
shopt -s histappend checkwinsize

export EDITOR="${EDITOR:-vim}"
export PAGER="${PAGER:-less}"
export LESS="${LESS:--R}"

alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status'
alias gd='git diff'
alias gl='git log --oneline --graph --decorate'

__contagent_branch() {
    local branch
    branch="$(git branch --show-current 2>/dev/null)" || return 0
    [ -n "$branch" ] && printf ' (%s)' "$branch"
}

PS1='\[\e[38;5;110m\]\u@contagent\[\e[0m\]:\[\e[38;5;180m\]\w\[\e[38;5;108m\]$(__contagent_branch)\[\e[0m\]\$ '
