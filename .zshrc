# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH=/Users/tomas.knoetze/.oh-my-zsh

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
ZSH_THEME="robbyrussell"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

ZLE_REMOVE_SUFFIX_CHARS="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
export SSH_KEY_PATH="~/.ssh/rsa_id"

# User
export DEFAULT_USER=tomas.knoetze

# Custom Aliases and Functions

# IPython

alias ipython='python -m IPython'

# Jump

function jump {
   if [ -z "$1" ]
     then
         ssh -A `whoami`@jump-box.takealot.com
     else
         ssh -A -t `whoami`@jump-box.takealot.com "ssh $1"
     fi
}

# Virtual Env

export WORKON_HOME=~/virtualenvs
source /usr/local/bin/virtualenvwrapper.sh

# Kubernetes
source <(kubectl completion zsh)
alias kubectl-prod='kubectl --context production'
alias helm-prod='helm --kube-context production'
alias stern-prod='stern --context production'

alias helm-office='helm --kube-context kubernetes-admin@kubernetes'

alias kubectl-office='kubectl --context kubernetes-admin@kubernetes'
alias kubectl-master='kubectl --context kubernetes-admin@kubernetes -n master'

alias stern-office='stern --context kubernetes-admin@kubernetes'
alias stern-master='stern --context kubernetes-admin@kubernetes -n master'

alias restart-dns='kubectl delete rc kube-dns-skywriter -n kube-system && kubectl apply -f ~/workspace/tal-kubernetes/specs/dev/skywriter/skydns-rc.yaml'

# Shorthand
alias k=kubectl

alias km=kubectl-master
alias sm=stern-master
alias kp=kubectl-prod
alias sp=stern-prod

alias hdel='helm del --purge'
alias kgp='kubectl get pods'
alias kgpw='watch -n 5 kubectl get pods'
alias kdel='kubectl delete pod'

function kex {
    kubectl exec $1 -it -- bash
}

function kmex {
    kubectl-master exec $1 -it -- bash
}

function kmg {
    echo "kubectl-master get pods | grep" $1
    km get pods | grep $1
}

function kenv {
export ENV_NAME=$1
alias kubectl-env='kubectl --context kubernetes-admin@kubernetes --namespace $ENV_NAME'
alias stern-env='stern --context kubernetes-admin@kubernetes --namespace $ENV_NAME'
alias helm-env='helm --kube-context kubernetes-admin@kubernetes --namespace $ENV_NAME'
}

# Git functions

alias gst='git status'

function info() {
  echo "$(tput setaf 7)$1$(tput sgr0)"
}
function code-on() {
  # Checkout a new branch for a Jira issuea
  # params:
  #   $1 jira issue key
  #   $2 tracking branch (default: master)
  (
    set -e
    local upstream=${2:=master}
    local branch=$1
    info "creating local branch '$branch' which tracks 'origin/${upstream}'"
    (
      set -x
      git checkout -b $branch origin/${upstream}
      git pull --rebase
    )
  )
}
function code-push() {
  # Push branch to the matching branch on the remote
  # Use this to update pull requests.
  (
    set -e
    local branch=`git rev-parse --abbrev-ref HEAD`
    [[ "$branch" == "master" ]] && echo "should be on feature branch" && return 1
    info "pushing to remote branch 'origin/$branch'"
    (
      set -x
      git push origin HEAD:$branch $@
    )
  )
}
function link-pr-jira() {
  # Tell Jira that we've created the PR and link it
  # Params:
  #   $1 The pull request url
  (
  local pr=$1
  if [ -z $pr ]; then
    info "pull request link not given, not linking to jira"
    return
  fi
  set -e
  local repo=`git remote -v | grep fetch | grep -o 'TAKEALOT/[^.]*' | cut -d '/' -f2`
  local branch=`git rev-parse --abbrev-ref HEAD`
  local issue=${branch#*-}
  local jirabase="https://jira.takealot.com/jira/rest/api/latest"
  local pr_description=${pr#*github.com/}
  info "linking pull request $pr to jira issue $issue"
  (
    set -x
    curl --netrc -X POST -H "Content-Type: application/json" $jirabase/issue/$issue/remotelink --data-raw "{\"object\": {\"url\":\"$pr\", \"title\": \"$pr_description\"}}"
  )
  )
}
function code-pr() {
  # Create a pull request from your branch to the upstream
  # Requires hub (tool from github)
  # Automatically uses the last commit message as the pr message
  (
  set -e
  local branch=`git rev-parse --abbrev-ref HEAD`
  local upstream=`git rev-parse --abbrev-ref HEAD@{upstream}`
  local short_upstream=${upstream#origin/}
  [[ "$branch" == "master" ]] && echo "should be on feature branch" && return 1
  code-push
  info "creating pull request from '$branch' to '$short_upstream'"
  (
    set -x
    local pr=`hub pull-request -h $branch -b $short_upstream -F <(git log -1 --pretty=%B)| grep -o 'http[^ ]*'`
    set +x
    link-pr-jira "$pr"
  )
  )
}
function code-release() {
  # This will just push the code to the remote branch
  # and also to the upstream. Pushing to both locations
  # will cause the existing pr to close.
  # This will also remove the local and remote branches
  (
  set -e
  local branch=`git rev-parse --abbrev-ref HEAD`
  local upstream=`git rev-parse --abbrev-ref HEAD@{upstream}`
  [[ "$branch" == "master" ]] && echo "should be on feature branch" && return 1
  git fetch
  code-push
  info "preparing release of 'origin/$branch' into '$upstream'"
  git status
  sleep 3
  info "pushing to remote branch '$upstream'"
  (
    set -x
    git push
  )
  info "cleaning up"
  (
    set -x
    git checkout master
    git reset --hard origin/master
    git push origin :${branch}
    git branch -d ${branch}
  )
  )
}
function code-abandon-local() {
  (
  set -e
  local branch=`git rev-parse --abbrev-ref HEAD`
  local upstream=`git rev-parse --abbrev-ref HEAD@{upstream}`
  [[ "$branch" == "master" ]] && echo "should be on feature branch" && return 1
  [[ -z "$upstream" ]] && echo "sanity failure; upstream is empty?" && return 1
    (
      set -x
      git checkout master
      git branch -d ${branch}
    )
  )
}
export PATH="/usr/local/opt/protobuf@2.6/bin:$PATH"
