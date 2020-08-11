#!/usr/bin/env bash
# These must run as the default non-privileged user.

# check sudo and password
sudo id || exit

# local functions
function section {
        echo -e "\e[33m\e[1m\n\n###\n### $*\e[0m"
}
function log {
        echo -e "\e[33m\e[1m\n### $*\e[0m"
}


section "Create a temp dir"
TEMPPATH="$(mktemp -d)"
log "Temporary storage : $TEMPPATH"

section "Save distro"
DISTRO=$(sed -rn '/CODENAME/ s/.*=//p' /etc/lsb-release)
log "Identified Distro : $DISTRO"

section "Add pre-install requirements"
sudo apt install -y gnupg build-essential

section "Fix nanosleep for WSL, restoring the old behaviour of nanosleep() to use CLOCK_MONOTONIC"
cat > $TEMPPATH/nanosleep.c << EOL
#define  _GNU_SOURCE
#include <time.h>
#include <unistd.h>
#include <signal.h>
#include <sys/epoll.h>
#include <dlfcn.h>
int nanosleep(const struct timespec *req, struct timespec *rem) {
    return clock_nanosleep(CLOCK_MONOTONIC, 0, req, rem);
}
int usleep(useconds_t usec) {
    struct timespec req = { .tv_sec     = (usec / 1000000), .tv_nsec    = (usec % 1000000) * 1000, };
    return nanosleep(&req, NULL);
}
static int min(int a, int b) { return a < b ? a : b; }
static int (*waitfn)(int fd, struct epoll_event *events, int maxevents, int timeout, const __sigset_t *ss) = 0;
int epoll_pwait(int fd, struct epoll_event *events, int maxevents, int timeout, const __sigset_t *ss) {
  if (!waitfn)
    waitfn = (int (*)(int fd, struct epoll_event *events, int maxevents, int timeout, const __sigset_t *ss)) dlsym(RTLD_NEXT, "epoll_pwait");
  while (1) {
    int r = waitfn(fd, events, maxevents, 0, ss);
    if (r > 0 || timeout == 0)
      return r;
    if (timeout < 0)
      usleep(100 * 10000);
    else {
      int s = min(1000, timeout);
      timeout -= s;
      usleep(s * 1000);
    }
  }
  return -1;
}
EOL
gcc -shared -fPIC -o "$TEMPPATH/libnanosleep.so" "$TEMPPATH/nanosleep.c"
sudo mv "$TEMPPATH/libnanosleep.so" /usr/local/lib/libnanosleep.so
echo /usr/local/lib/libnanosleep.so | sudo tee -a /etc/ld.so.preload > /dev/null

section "Switch apt to https mirror"
sudo sed -i '/^deb/ s,http://archive.ubuntu.com/ubuntu/,https://mirrors.edge.kernel.org/ubuntu/,' /etc/apt/sources.list

section "Include repos"
curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
echo "deb https://deb.nodesource.com/node_12.x $DISTRO main" | sudo tee /etc/apt/sources.list.d/nodesource.list > /dev/null
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E1DD270288B4E6030699E45FA1715D88E1DF1F24
echo "deb http://ppa.launchpad.net/git-core/ppa/ubuntu/ $DISTRO main" | sudo tee /etc/apt/sources.list.d/git-core.list > /dev/null

curl -s https://packages.microsoft.com/config/ubuntu/19.10/packages-microsoft-prod.deb -o $TEMPPATH/packages-microsoft-prod.deb
sudo dpkg -i $TEMPPATH/packages-microsoft-prod.deb

section "Ensure we have the latest packages"
sudo apt update
sudo apt -y full-upgrade

section "Make sure we have the required libraries and tools already installed before starting."
sudo apt install -y \
  lsb-release build-essential curl wget gettext \
  nmap ncat mosh \
  vim git \
  nodejs rustc dotnet-sdk-3.1 aspnetcore-runtime-3.1 dotnet-runtime-3.1\
  jq unzip mmv \
  fish

section "Install cli tools from rust"
cargo install hyperfine sd hx exa bat ripgrep fd-find

section "Install winbind and support lib to ping WINS hosts"
sudo apt install -y winbind libnss-winbind
# need to append to the /etc/nsswitch.conf file to enable if not already done ...
if ! grep -qc 'wins' /etc/nsswitch.conf ; then
  sudo sed -i '/hosts:/ s/$/ wins/' /etc/nsswitch.conf
fi

section "Basic .npmrc"
echo prefix=$HOME/.local/ >> ~/.npmrc
npm install -g npm

section "Basic .gitconfig"
cat > ~/.gitconfig << EOL
[user]
        name = Bruno Schmidt
        email = bruno.schmidt@gmail.com
[core]
        checkStat = minimal
[alias]
        st = status
        co = checkout
        br = branch
        ci = commit
        cl = clone
        lol = log --graph --decorate --pretty=oneline
	lola = log --graph --decorate --pretty=oneline --abbrev-commit --all
        amend = commit --amend
[push]
        default = simple
[credential]
        helper = store
[color]
        ui = True
[status]
        showUntrackedFiles = all
[url "https://github.com/"]
        insteadOf = gh
EOL

section "Basic .bash_aliases"
cat > ~/.bash_aliases << EOL
#alias ls="ls -vh --color=auto"
alias ls="exa -gbH"
alias l="ls -l --git"
alias ll="ls -laF"
alias g="git"
alias map="xargs -n1"
EOL

section "Basic fish config"
mkdir -p ~/.config/fish/conf.d/
cat > ~/.config/fish/conf.d/welcome.fish << EOL
function fish_greeting
        update-motd --show-only
end
EOL

section "Basic fish aliases"
cat > ~/.config/fish/conf.d/alias.fish << EOL
#alias ls "ls -vh --color=auto"
alias ls "exa -gbH"
alias l "ls -l --git"
alias ll "ls -laF"
alias g "git"
alias map "xargs -n1"
EOL

section "Fish load profile"
cat > ~/.config/fish/conf.d/profile.fish << EOL
status --is-login; and fenv ~/.profile
EOL

section "Profile PATH to cargo bins"
cat >> ~/.profile << EOL
# Set PATH so it includes user's private Cargo bin if it exists
if [ -d "$HOME/.cargo/bin" ] ; then
    PATH="$HOME/.cargo/bin:$PATH"
fi
EOL

section "Install omf"
curl -L https://get.oh-my.fish > "$TEMPPATH/installer.fish"
chmod +x "$TEMPPATH/installer.fish"
"$TEMPPATH/installer.fish" --noninteractive
fish -c "omf install agnoster"

section "Install fish helpers"
fish -c "omf install foreign-env bass"

section "Enable UNC paths at cmd.exe to allow access to \\$wsl\"
which reg.exe >/dev/null && reg.exe add "HKCU\Software\Microsoft\Command Processor" /v DisableUNCCheck /t REG_DWORD /d 0x1 /f


section "You now need to close and restart the Bash shell"
rm -rf "$TEMPPATH"