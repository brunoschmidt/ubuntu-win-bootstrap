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
# echo "deb http://ppa.launchpad.net/git-core/ppa/ubuntu/ $DISTRO main" | sudo tee /etc/apt/sources.list.d/git-core.list > /dev/null

# ensure we have the latest packages
sudo apt update
sudo apt -y full-upgrade

# make sure we have the required libraries and tools already installed before starting.
sudo apt install -y \
  lsb-release build-essential curl wget gettext \
  nmap ncat \
  vim git \
  nodejs \
  rustc \
  fish

# install winbind and support lib to ping WINS hosts
sudo apt install -y winbind libnss-winbind
# need to append to the /etc/nsswitch.conf file to enable if not already done ...
if ! grep -qc 'wins' /etc/nsswitch.conf ; then
  sudo sed -i '/hosts:/ s/$/ wins/' /etc/nsswitch.conf
fi

# basic .gitconfig
sudo tee ~/.gitconfig > /dev/null << EOL
[alias]
        st = status
        co = checkout
        br = branch
        ci = commit
        cl = clone
[push]
        default = current
[credential]
        helper = cache --timeout 3600
EOL

# basic .bash_aliases
sudo tee ~/.bash_aliases > /dev/null << EOL
alias ls="ls -vh --color=auto"
alias l="ls -l"
EOL

# install omf
curl -L https://get.oh-my.fish | fish
fish -c "omf install agnoster"

echo
echo "You now need to close and restart the Bash shell"
