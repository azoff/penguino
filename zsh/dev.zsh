eval "$(nodenv init -)"
export PATH="${PATH}:$(nodenv root)/versions/$(nodenv version-name)/bin" 

alias dcc='docker-compose'
alias dcu='docker-compose up'
alias dcx='docker-compose exec'
alias dcr='docker-compose run --rm'
alias dck='docker-compose kill && docker-compose rm-vf'
