# docs: https://github.com/geometry-zsh/geometry
ZSH_THEME="geometry"

# zsh history setup
HISTFILE=${ZSH_HOME}/.histfile
HISTSIZE=1000
SAVEHIST=1000

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
HYPHEN_INSENSITIVE="true"

# Uncomment the following line if pasting URLs and other text is messed up.
DISABLE_MAGIC_FUNCTIONS="true"

# When a partial line is preserved, by default you will see an 
# inverse+bold character at the end of the partial line: a "%" for 
# a normal user or a "#" for root. If set, the shell parameter 
# PROMPT_EOL_MARK can be used to customize how the end of partial 
# lines are shown.
PROMPT_EOL_MARK=

plugins=(git \
	# autocomplete with tab outs \
	zsh-autosuggestions \
  # esc twice to retry with sudo \
	sudo \
	# pwd | pbcopy \
	copydir \
	# cat file | pbcopy \
	copyfile \
	# ctrl+o to copy history to the clipboard	\
	copybuffer \
	# alt+horizontal for time, alt+vertical for folders \
	dirhistory)

source $ZSH/oh-my-zsh.sh

GEOMETRY_STATUS_SYMBOL="•"             # default prompt symbol
GEOMETRY_STATUS_SYMBOL_ERROR="•"       # displayed when exit value is != 0