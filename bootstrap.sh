#!/usr/bin/env bash
# these will run as the default non-privileged user.

# save the path to this script for later use
THISPATH="$(dirname $(readlink -f "$0"))"
echo "We are running from : $THISPATH"

# save distro
DISTRO=$(sed -rn '/CODENAME/ s/.*=//p' /etc/lsb-release)
echo "Identified Distro : $DISTRO"

# add pre-install requirements
sudo apt install -y gnupg

# switch apt to https mirror
sudo sed -i '/^deb/ s,http://archive.ubuntu.com/ubuntu/,https://mirrors.edge.kernel.org/ubuntu/,' /etc/apt/sources.list

# include repos
curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
echo "deb https://deb.nodesource.com/node_12.x $DISTRO main" | sudo tee /etc/apt/sources.list.d/nodesource.list > /dev/null
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E1DD270288B4E6030699E45FA1715D88E1DF1F24
echo "deb http://ppa.launchpad.net/git-core/ppa/ubuntu/ $DISTRO main" | sudo tee /etc/apt/sources.list.d/git-core.list > /dev/null

# ensure we have the latest packages
sudo apt update
sudo apt -y full-upgrade

# make sure we have the required libraries and tools already installed before starting.
sudo apt install -y \
  lsb-release build-essential curl wget gettext \
  nmap ncat \
  vim git \
  nodejs jq\
  rustc \
  ripgrep fd-find bat \
  fish

cargo install hyperfine sd hx exa

# install winbind and support lib to ping WINS hosts
sudo apt install -y winbind libnss-winbind
# need to append to the /etc/nsswitch.conf file to enable if not already done ...
if ! grep -qc 'wins' /etc/nsswitch.conf ; then
  sudo sed -i '/hosts:/ s/$/ wins/' /etc/nsswitch.conf
fi

# basic .npmrc
echo prefix=$HOME/.local/ >> ~/.npmrc
npm install -g npm

# basic .gitconfig
cat > ~/.gitconfig << EOL
[user]
        name = Bruno Schmidt
        email = bruno.schmidt@gmail.com
[alias]
        st = status
        co = checkout
        br = branch
        ci = commit
        cl = clone
        lol = log --graph --decorate --pretty=oneline
	lola = log --graph --decorate --pretty=oneline --abbrev-commit --all
        ammend = commit --amend
[push]
        default = simple
[credential]
        helper = cache --timeout 3600
[color]
    ui = True
[status]
    showUntrackedFiles = all
[url "https://github.com/"]
    insteadOf = gh
EOL

# basic .bash_aliases
cat > ~/.bash_aliases << EOL
#alias ls="ls -vh --color=auto"
alias ls="exa -gbH"
alias l="ls -l --git"
alias ll="ls -laF"
alias g="git"
alias map="xargs -n1"
EOL

# basic fish aliases
mkdir -p ~/.config/fish/conf.d/
cat > ~/.config/fish/conf.d/alias.fish << EOL
#alias ls "ls -vh --color=auto"
alias ls "exa -gbH"
alias l "ls -l --git"
alias ll "ls -laF"
alias g "git"
alias map "xargs -n1"
EOL

# fish load profile
cat > ~/.config/fish/conf.d/profile.fish << EOL
status --is-login; and fenv ~/.profile
EOL

# profile PATH to cargo bins
cat >> ~/.profile << EOL
# set PATH so it includes user's private Cargo bin if it exists
if [ -d "$HOME/.cargo/bin" ] ; then
    PATH="$HOME/.cargo/bin:$PATH"
fi
EOL

# install omf
curl -L https://get.oh-my.fish | fish
fish -c "omf install agnoster"

# install fish helpers
fish -c "omf install foreign-env bass"

# Enable UNC paths at cmd.exe to allow access to \\$wsl\
which reg.exe >/dev/null && reg.exe add "HKCU\Software\Microsoft\Command Processor" /v DisableUNCCheck /t REG_DWORD /d 0x1 /f

echo
echo "You now need to close and restart the Bash shell"
