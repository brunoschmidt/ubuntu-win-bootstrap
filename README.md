# Bootstrap script for the Windows Subsystem for Linux (WSL)

This is a very simple (for now) script to set up a NEW UNMODIFIED [`Windows Subsystem for Linux`][wsl] (WSL hereafter) with the following functionality :

* Updated to the latest package versions from Ubuntu upstream.
* Have the `build-essential` package installed plus all required support libraries to enable the below functionality to work.
* Fix for `nanosleep` bug on WSL1
* Enable resolution of WINS hostnames
* [`Git`][git] installed with git-flow. A skeleton `.gitconfig` will be set up with a few aliases.
* [`GitHub CLI`][gh]
* [`Node.js`][node] with npm prefix pointing to `~/.local/`.
* Rust compiler
* DotNet Core SDK 3.1 with ASP and Powershell
* Network tools like `nmap`, `ncat`, `mosh`
* Fish shell with OMFish, `agnoster` theme and profile loading with `foreign-env`
* Various shell tools like: `sd`, `hx`, `fd`, `exa`, `bat`, `ripgrep`
* Various dev tools like: `jq`, `hyperfine`
* Various bash and fish tunnings to have same aliases, profiles and configs

Note also since WSL is basically just a standard Ubuntu installation this sctipt should also work unmodified on an Ubuntu Distribution, though currently untested.

**Please read all of this file before starting**

## Usage
The simplest way to use this script is to clone into a completely new WSL environment. If you already have a configured WSL system there are instructions below on how to reset this to 'factory' defaults __[TODO]__.

From within WSL run the following:
```
git clone https://github.com/brunoschmidt/ubuntu-win-bootstrap.git
cd ubuntu-win-bootstrap
./bootstrap.sh
```

Single Line Version:
```
curl https://raw.githubusercontent.com/brunoschmidt/ubuntu-win-bootstrap/master/bootstrap.sh | bash
```

[wsl]: https://msdn.microsoft.com/commandline/wsl/about
[git]: https://git-scm.com
[node]: https://nodejs.org
[gh]: https://cli.github.com/