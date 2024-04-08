# node 
eval "$(nodenv init -)"

# ruby
eval "$(~/.rbenv/bin/rbenv init -)"

# bun completions
[ -s "/home/azoff/.bun/_bun" ] && source "/home/azoff/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# android
export ANDROID_SDK_ROOT=~/Android/Sdk

# rust
. "$HOME/.cargo/env"

# user-specific binaries
if [ -d "$HOME/bin" ] ; then
    export PATH="$HOME/bin:$PATH"
fi
if [ -d "$HOME/.local/bin" ] ; then
    export PATH="$HOME/.local/bin:$PATH"
fi