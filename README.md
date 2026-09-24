# Workstation Configuration

This system uses NixOS + Home Manager with Git as the source of truth for user configuration.

## Configuration layout

```text
/etc/nixos/configuration.nix
~/.config/home-manager/
├── flake.nix
├── flake.lock
├── home.nix
├── hosts/
│   ├── x200s.nix
│   └── mac.nix
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
* `emacs/init.el` — portable Emacs behavior and package configuration.
* `flake.nix` — composes shared and host-specific modules into deployable Home Manager configurations.
* `flake.lock` — pins Nixpkgs and Home Manager revisions.

The current ThinkPad Home Manager target is:

```sh
home-manager switch --flake '.#daws@x200s'
```

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
~/.config/home-manager/emacs/
```

to:

```text
~/.config/emacs/
```

Edit the source files under `~/.config/home-manager/emacs/`, then run Home Manager to deploy them.

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

Home Manager provides packages and files on both Linux and macOS. macOS does not currently use nix-darwin; only developer/user configuration is intended to be portable.

Machine-specific behavior should remain outside shared `home.nix` whenever practical.

## Guiding rule

Treat the repository as the source of truth. Avoid manually mutating generated files such as:

```text
~/.config/emacs
~/.config/git/config
```

Edit their source configuration instead, apply the configuration, test it, then commit the result.
	
