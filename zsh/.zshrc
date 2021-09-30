bindkey -e # emacs mode

ZSH_HOME="$(dirname "$(readlink ~/.zshrc)")"
ZSH="${ZSH_HOME}/oh-my-zsh"
source ${ZSH_HOME}/exports.zsh
source ${ZSH_HOME}/opts.zsh
source ${ZSH_HOME}/aliases.zsh
source ${ZSH_HOME}/prompt.zsh
source ${ZSH_HOME}/dev.zsh
