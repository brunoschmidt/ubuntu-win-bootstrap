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

if [ "0" -eq "$(id -u)" ]; then
        section "These must run as the default non-privileged user with sudo access."
        exit
fi

section "Create a temp dir"
TEMPPATH="$(mktemp -d)"
log "Temporary storage : $TEMPPATH"

section "Save distro"
DISTRO=$(sed -rn '/CODENAME/ s/.*=//p' /etc/lsb-release)
DISTRO_RELEASE=$(sed -rn '/RELEASE/ s/.*=//p' /etc/lsb-release)
log "Identified Distro : $DISTRO"
log "Identified Distro Release: $RELEASE"

section "Create a '.local/bin'"
[ -d ~/.local/bin ] || mkdir -p ~/.local/bin

section "Add pre-install requirements"
sudo apt update
sudo apt install -y gnupg build-essential pkg-config dirmngr

if [ `which wsl.exe` ]; then
        section "Fix nanosleep for WSL, restoring the old behaviour of nanosleep() to use CLOCK_MONOTONIC"
        cat > $TEMPPATH/nanosleep.c << 'EOL'
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
fi

section "Switch apt to https mirror"
sudo sed -i '/^deb/ s,http://archive.ubuntu.com/ubuntu/,https://mirrors.edge.kernel.org/ubuntu/,' /etc/apt/sources.list

section "Include repos"
curl -s https://deb.nodesource.com/gpgkey/nodesource.gpg.key | sudo apt-key add -
echo "deb https://deb.nodesource.com/node_12.x $DISTRO main" | sudo tee /etc/apt/sources.list.d/nodesource.list > /dev/null
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E1DD270288B4E6030699E45FA1715D88E1DF1F24
echo "deb http://ppa.launchpad.net/git-core/ppa/ubuntu/ $DISTRO main" | sudo tee /etc/apt/sources.list.d/git-core.list > /dev/null
sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-key C99B11DEB97541F0
echo "deb https://cli.github.com/packages $DISTRO main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
curl -s https://packages.microsoft.com/config/ubuntu/$DISTRO_RELEASE/packages-microsoft-prod.deb -o $TEMPPATH/packages-microsoft-prod.deb
sudo dpkg -i $TEMPPATH/packages-microsoft-prod.deb

section "Ensure we have the latest packages"
sudo apt update
sudo apt -y full-upgrade

section "Make sure we have the required libraries and tools already installed before starting."
sudo apt install -y \
  lsb-release build-essential gettext \
  nmap ncat mosh curl wget \
  vim git git-flow gh \
  nodejs rustc dotnet-sdk-5.0 aspnetcore-runtime-5.0 dotnet-runtime-5.0 \
  jq unzip mmv \
  fish

section "Install cli tools from rust"
cargo install hyperfine sd hx exa bat ripgrep fd-find

section "Install Powershell Core"
dotnet tool install -g powershell

section "Install Deno"
export DENO_INSTALL=~/.local
curl -fsSL https://deno.land/x/install/install.sh | sh
cat >> ~/.config/shell/profile.d/40-dotnet-telemetry.sh << 'EOL'
export export DENO_INSTALL=~/.local
EOL

section "Install winbind and support lib to ping WINS hosts"
sudo apt install -y winbind libnss-winbind
# need to append to the /etc/nsswitch.conf file to enable if not already done ...
if ! grep -qc 'wins' /etc/nsswitch.conf ; then
  sudo sed -i '/hosts:/ s/$/ wins/' /etc/nsswitch.conf
fi

section "User Shell profile config dir"
mkdir -p ~/.config/shell/profile.d/
cat >> ~/.profile << 'EOL'

# Load general profile configurations
if [ -d ~/.config/shell/profile.d ]; then
        for i in ~/.config/shell/profile.d/*.sh; do
                if [ -r $i ]; then
                        . $i
                fi
        done
        unset i
fi
EOL

section "Basic .npmrc"
echo prefix=$HOME/.local/ >> ~/.npmrc
npm install -g npm

section "Basic .ssh"
mkdir -p ~/.ssh/config.d
cat > ~/.ssh/config << 'EOL'
# base configuration(s)
Include config.d/*
EOL
cat > ~/.ssh/config.d/00-base-ssh.conf << 'EOL'
# Prevent timeouts on devboxes
ServerAliveInterval 30
ServerAliveCountMax 4

Host *
	ForwardAgent yes
EOL

section "Basic .gitconfig"
cat > ~/.gitconfig << 'EOL'
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
        f = flow
[push]
        default = simple
[credential]
        helper = store
[color]
        ui = True
[status]
        showUntrackedFiles = all
[diff]
        algorithm = histogram
[url "https://github.com/"]
        insteadOf = gh
[url "git@github.com:brunoschmidt/"]
        insteadOf = bbs:
[url "abcbrasil@vs-ssh.visualstudio.com:v3/abcbrasil/"]
        insteadOf = abc:
EOL

section "Basic .bash_aliases"
cat > ~/.bash_aliases << 'EOL'
#alias ls="ls -vh --color=auto"
alias ls="exa -gbH --group-directories-first"
alias l="ls -l --git"
alias ll="ls -laF"
alias g="git"
alias gf="git flow"
alias map="xargs -n1"
alias open="wslview"
EOL

section "Basic fish config"
mkdir -p ~/.config/fish/conf.d/
cat > ~/.config/fish/conf.d/welcome.fish << 'EOL'
function fish_greeting
        # update-motd --show-only
end
EOL

section "Basic fish aliases"
mkdir -p ~/.config/fish/conf.d/
cat > ~/.config/fish/conf.d/alias.fish << 'EOL'
#alias ls "ls -vh --color=auto"
alias ls "exa -gbH --group-directories-first"
alias l "ls -l --git"
alias ll "ls -laF"
alias g "git"
alias gf "git flow"
alias map "xargs -n1"
alias open "wslview"
EOL

section "Fish load profile"
cat > ~/.config/fish/conf.d/profile.fish << 'EOL'
status --is-login; and fenv 'source ~/.profile'
EOL

section "Profile PATH to cargo bins"
cat >> ~/.config/shell/profile.d/80-rust-cargo.sh << 'EOL'
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

section "Install ohmy-posh"
pwsh -Command 'Install-Module posh-git -Scope CurrentUser -Force -Confirm'
pwsh -Command 'Install-Module oh-my-posh -Scope CurrentUser -Force -Confir'
pwsh -Command 'Install-Module -Name PSReadLine -AllowPrerelease -Scope CurrentUser -Force -SkipPublisherCheck'
mkdir -p ~/.config/powershell
cat >> ~/.config/powershell/Microsoft.PowerShell_profile.ps1 << 'EOL'
Import-Module posh-git
Import-Module oh-my-posh
Set-Theme Agnoster
EOL

section "Install cheat.sh"
curl https://cht.sh/:cht.sh > ~/.local/bin/cht.sh
chmod +x ~/.local/bin/cht.sh

section "PATH to DotNet tools bins"
cat >> ~/.config/shell/profile.d/80-dotnet-tools.sh << 'EOL'
# Set PATH so it includes user's private DotNet Tools bin if it exists
if [ -d "$HOME/.dotnet/tools" ] ; then
    PATH="$HOME/.dotnet/tools:$PATH"
fi
EOL

section "Disable DotNet Telemetry"
cat >> ~/.config/shell/profile.d/40-dotnet-telemetry.sh << 'EOL'
# Optout of DotNet Telemetry
export DOTNET_CLI_TELEMETRY_OPTOUT=1
EOL

section "Enable UNC paths at cmd.exe to allow access to \\\\$wsl\\"
which reg.exe >/dev/null && reg.exe add "HKCU\Software\Microsoft\Command Processor" /v DisableUNCCheck /t REG_DWORD /d 0x1 /f

section "Enable Windows LongPath support breaking very old Win32 compatibility"
which reg.exe >/dev/null && reg.exe add "HKLM\SYSTEM\CurrentControlSet\Control\FileSystem" /v LongPathsEnabled /t REG_DWORD /d 0x1 /f

section "You now need to close and restart the Bash shell"
rm -rf "$TEMPPATH"
