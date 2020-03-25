# Bootstrap script for the Windows Subsystem for Linux (WSL)

This is a very simple (for now) script to set up a NEW UNMODIFIED [`Windows Subsystem for Linux`][wsl] (WSL hereafter) with the following functionality :

* Updated to the latest package versions from Ubuntu upstream.
* Have the `build-essential` package installed plus all required support libraries to enable the below functionality to work.
* The Latest version of [`Git`][git] installed. A skeleton `.gitconfig` will be set up with a few aliases.
* [`Node.js`][node] the most recent LTS version.
* Enable resolution of WINS hostnames
* Rust compiler
* Nmap and Ncat
* Fish shell with OMFish

Note also since WSL is basically just a standard Ubuntu installation this sctipt should also work unmodified on an Ubuntu Distribution, though currently untested.

**Please read all of this file before starting**

## Usage
The simplest way to use this script is to clone into a completely new WSL environment. If you already have a configured WSL system there are instructions below on how to reset this to 'factory' defaults __[TODO]__.
From within WSL run the following:
```
git clone https://github.com/seapagan/ubuntu-win-bootstrap.git
cd ubuntu-win-bootstrap
./bootstrap.sh
```

[wsl]: https://msdn.microsoft.com/commandline/wsl/about
[git]: https://git-scm.com
[node]: https://nodejs.org
