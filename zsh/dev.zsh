# node 
# eval "$(nodenv init -)"
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# ruby
eval "$(~/.rbenv/bin/rbenv init -)"

# java
[ -z "$JAVA_HOME" ] && \
[ -x "$(command -v java)" ] && \
export JAVA_HOME=$(dirname $(dirname $(readlink -f $(which java))))

# bun completions
[ -s "/home/azoff/.bun/_bun" ] && source "/home/azoff/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# android
export ANDROID_SDK_ROOT=~/Android/Sdk

# playdate
export PLAYDATE_SDK_PATH=~/Playdate/Sdk

# rust
. "$HOME/.cargo/env"

# user-specific binaries
if [ -d "$HOME/bin" ] ; then
    export PATH="$HOME/bin:$PATH"
fi
if [ -d "$HOME/.local/bin" ] ; then
    export PATH="$HOME/.local/bin:$PATH"
fi