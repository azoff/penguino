eval "$(nodenv init -)"

export ANDROID_SDK_ROOT=~/Android/Sdk

alias dcc='docker-compose'
alias dcu='docker-compose up'
alias dcx='docker-compose exec'
alias dcr='docker-compose run --rm'
alias dck='docker-compose kill && docker-compose rm-vf'
