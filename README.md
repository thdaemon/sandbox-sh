# sandbox-sh

sandbox-sh is an easy-to-use, unprivileged sandbox bootstrapper powered by
Bubblewrap and xdg-dbus-proxy. It creates a constrained environment for desktop 
sandboxing: sharing GUI sockets (X11/Wayland), audio, DRI, and user-specified 
paths while keeping a minimal filesystem view.

## Requirements

- Bash 5.3+
- `bubblewrap` 0.11+
- `xdg-dbus-proxy` 0.1+

## Install

```sh
sudo make install
sudo mandb
```

## Usage

see [sandbox.sh\(1\)](docs/sandbox.sh.1.adoc) man-page.
