# Workstation Configuration

This system uses NixOS + Home Manager with Git as the source of truth for user configuration.

## Configuration layout

```text
/etc/nixos/configuration.nix
~/repos/nix-config/
├── flake.nix
├── flake.lock
├── home.nix
├── hosts/
│   ├── x200s.nix
│   └── mac.nix
├── darwin/
│   └── mini.nix
└── emacs/
    ├── init.el
    └── early-init.el
```

*hosts/ will likely be refactored into something closer to platforms/{linux/, mac/} and then machine specific like x200s, mac-laptop, rapsberry-pi, etc. Similarly, right now, init.el holds macos specific adjustments. If that grows too much, we'll adjust. 

Responsibilities:

* `/etc/nixos/configuration.nix` — machine/system configuration: kernel, bootloader, networking, Xorg, services, hardware.
* `home.nix` — user configuration shared across machines: CLI tools, Git/GitHub, Emacs and Emacs packages.
* `hosts/x200s.nix` — user-level configuration specific to the ThinkPad X200s, including launching EXWM.
* `hosts/mac.nix` — macOS-specific Home Manager settings.
* `darwin/mini.nix` — the Mac mini M4's machine configuration (nix-darwin): Tailscale, SSH, power, system tools. The Mac counterpart of `/etc/nixos/configuration.nix`. Apply with `sudo darwin-rebuild switch --flake ~/repos/nix-config#mini` (the first time, `sudo nix run nix-darwin -- switch --flake ~/repos/nix-config#mini`).
* `emacs/init.el` — portable Emacs behavior and package configuration.
* `flake.nix` — composes shared and host-specific modules into deployable Home Manager configurations.
* `flake.lock` — pins Nixpkgs and Home Manager revisions.

The current ThinkPad Home Manager target is:

```sh
home-manager switch --flake '.#daws@x200s'
```

## New Mac

Install nothing else by hand first: anything installed outside Nix (gh, Tailscale, etc.) will clash with what the switch manages. The repo is public and holds no secrets, so cloning needs no login.

```sh
# 1. Install Nix (once). Then open a new Terminal window.
curl -fsSL https://install.determinate.systems/nix | sh -s -- install

# 2. Clone this repo (git from Nix, so nothing else is installed).
nix run nixpkgs#git -- clone https://github.com/dawson-shay/nix-config.git ~/repos/nix-config

# 3. Machine config (nix-darwin): hostname, Tailscale, SSH, power.
sudo nix run nix-darwin -- switch --flake ~/repos/nix-config#mini

# 4. Open a new Terminal window (only new login shells pick up nix-darwin's
#    tools on PATH), then join the tailnet.
sudo tailscale up

# 5. User config (Home Manager): Emacs, git, gh, shell.
nix run home-manager -- switch --flake ~/repos/nix-config#<user>@<host>

# 6. Log in for real with the Nix-managed gh.
gh auth login
```

A new machine needs its own entries in `flake.nix` (`homeConfigurations` and, for a Mac, `darwinConfigurations`), with its username and home directory. If a switch stops because a file already exists, add `-b backup` to move the old file aside.

## Package management

Do not install persistent workstation tools imperatively when they should be reproducible.

Shared user tools belong in `home.nix`:

```nix
home.packages = [
  pkgs.tree
  pkgs.somePackage
];
```

Machine-level packages/services belong in `/etc/nixos/configuration.nix`.

Emacs packages are installed by Home Manager:

```nix
programs.emacs = {
  enable = true;

  extraPackages = epkgs: [
    epkgs.nix-mode
    epkgs.magit
    epkgs.exwm
  ];
};
```

Emacs Lisp configures those packages:

```elisp
(use-package magit
  :commands magit-status)
```

Do not use `package-install` or `use-package :ensure` for packages managed by Nix.

Temporary packages can be used without changing configuration:

```sh
nix shell nixpkgs#PACKAGE
```

## Emacs and EXWM

Home Manager deploys:

```text
~/repos/nix-config/emacs/
```

to:

```text
~/.config/emacs/
```

Edit the source files under `~/repos/nix-config/emacs/`, then run Home Manager to deploy them.

EXWM is installed through Home Manager and launched on the X200s using:

```elisp
(exwm-wm-mode)
```

The X server itself is enabled at the NixOS system level. EXWM can currently be launched from a TTY with:

```sh
startx ~/.xsession
```

## Git workflow

The Home Manager directory is a Git repository backed by GitHub.

Typical change:

```text
edit
→ home-manager switch --flake '.#daws@x200s'
→ test
→ stage
→ commit
→ push
```

Magit is the preferred Git interface inside Emacs.

GitHub authentication is handled by `gh`, with Git configured to use the `gh` credential helper.

## Cross-platform design

The shared Emacs configuration should remain ordinary portable Emacs Lisp.

Home Manager provides packages and files on both Linux and macOS. On macOS, nix-darwin (`darwin/mini.nix`) handles the machine level, as NixOS does on Linux; only developer/user configuration is intended to be portable.

Machine-specific behavior should remain outside shared `home.nix` whenever practical.

## Guiding rule

This repository is public: never commit secrets, tokens or keys to it, even encrypted. Secrets live in private repos as sops files (see tinytrader-ops) or outside git.

Treat the repository as the source of truth. Avoid manually mutating generated files such as:

```text
~/.config/emacs
~/.config/git/config
```

Edit their source configuration instead, apply the configuration, test it, then commit the result.
	
