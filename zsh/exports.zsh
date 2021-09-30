# Stops annoying ads in npm packages
export ADBLOCK=true

# Stops NextJS project tracking
export NEXT_TELEMETRY_DISABLED=1

# helps find go packages
export GOPATH="${HOME}/go"

# Allows for multiple node versions
export PATH="$ZSH_HOME/bin:$GOPATH/bin:$HOME/.nodenv/bin:$HOME/.local/bin:$PATH"

# https://github.com/lowply/zoom-launcher#configuration
export ZL_EMAIL="jon@sno.llc"
export ZL_REGEX="^(https|zoommtg)://zoom.us/.*$"

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='code --wait'
fi
