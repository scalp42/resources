##
# Paths
export PATH="/usr/local/bin:/usr/local/sbin:$PATH"

##
# Load RVM function
[[ -s "$HOME/.rvm/scripts/rvm" ]] && . "$HOME/.rvm/scripts/rvm"

##
# Git symbolic link and branch parser
function parse_git_branch {
  ref=$(git-symbolic-ref HEAD 2> /dev/null) || return
  echo "("${ref#refs/heads/}")"
}
PS1="\w \$(parse_git_branch)\$ "

##
# Custom aliases
alias ll="ls -al"
