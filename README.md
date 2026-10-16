# nix-config

My machines, with Git as the source of truth: Home Manager for the user
setup on every machine, nix-darwin for the Macs' machine level, and NixOS
(`/etc/nixos/configuration.nix`, outside this repo) on the ThinkPad.

| Machine | User config | Machine config |
|---|---|---|
| ThinkPad X200s | `homeConfigurations."daws@x200s"` | `/etc/nixos/configuration.nix` |
| Mac mini M4 (`mini`) | `homeConfigurations."dawsonshay@mini"` | `darwinConfigurations.mini` (`darwin/mini.nix`) plus tinytrader-ops' role |
| Other Macs | `homeConfigurations."daws@mac"` | none yet |

## Layout

```text
/etc/nixos/configuration.nix   the X200s's machine config (not in this repo)
~/repos/nix-config/
├── flake.nix          composes everything below into homeConfigurations and darwinConfigurations
├── flake.lock         pins nixpkgs, Home Manager, nix-darwin and tinytrader-ops
├── home.nix           user config shared by every machine
├── hosts/
│   ├── x200s.nix      user config for the X200s, including launching EXWM
│   └── mac.nix        macOS user settings (Home Manager owns zsh)
├── darwin/
│   └── mini.nix       the Mac mini M4's machine config (nix-darwin)
├── scripts/
│   └── switch         apply a Mac's nix-darwin config
├── ssh/config         ~/.ssh/config
└── emacs/
    ├── init.el
    └── early-init.el
```

Responsibilities:

* `/etc/nixos/configuration.nix`: machine/system configuration on the X200s: kernel, bootloader, networking, Xorg, services, hardware.
* `home.nix`: user configuration shared across machines: CLI tools, Git/GitHub, Emacs and Emacs packages, SSH config, and `~/.cargo/config.toml`, which points every checkout's Rust builds at one folder (`~/.cache/cargo-target`) so worktrees don't each leave a `target/` behind.
* `hosts/x200s.nix`, `hosts/mac.nix`: per-platform user settings.
* `darwin/mini.nix`: the Mac mini M4's machine configuration (nix-darwin), the Mac counterpart of `/etc/nixos/configuration.nix`: hostname, Tailscale, SSH (keys only), power (never sleeps, restarts after a power cut), system tools, and Colima, which runs the Docker engine as a boot daemon (`org.nixos.colima`), so containers come back after a reboot without anyone logging in.
* `emacs/init.el`: portable Emacs behavior and package configuration.

*hosts/ will likely be refactored into something closer to platforms/{linux/, mac/} and then machine specific like x200s, mac-laptop, rapsberry-pi, etc. Similarly, right now, init.el holds macos specific adjustments. If that grows too much, we'll adjust.

## Switching

User config, on any machine:

```sh
home-manager switch --flake ~/repos/nix-config#daws@x200s       # the ThinkPad
home-manager switch --flake ~/repos/nix-config#dawsonshay@mini  # the M4
```

Machine config on a Mac:

```sh
~/repos/nix-config/scripts/switch          # this Mac (mini)
~/repos/nix-config/scripts/switch HOST     # another darwinConfigurations entry
```

`scripts/switch` builds the configuration as you, then activates it as root
(it asks for your password). Don't use `sudo darwin-rebuild switch`: it
evaluates as root, which has no GitHub login, so it can't fetch the private
tinytrader-ops input.

On the X200s, the machine config is `sudo nixos-rebuild switch`.

## The tinytrader-ops role

`darwinConfigurations.mini` imports `tinytrader-ops.darwinModules.mini`: what
of the tinytrader deployment runs natively on this Mac (its monitor and
node_exporter). What runs where, and everything else about the deployment,
is defined in tinytrader-ops, not here; this repo owns the machine (users,
Tailscale, Colima).

tinytrader-ops is private, so building `#mini` needs GitHub access as you (gh
logged in, with git using it as the credential helper, which Home Manager
sets up). The role is taken at the revision `flake.lock` pins. To take a
change from tinytrader-ops:

```sh
cd ~/repos/nix-config
nix flake update tinytrader-ops
git commit -am "Take tinytrader-ops <rev>: <why>"
scripts/switch
```

## New Mac

Install nothing else by hand first: anything installed outside Nix (gh, Tailscale, etc.) will clash with what the switch manages. The repo is public and holds no secrets, so cloning needs no login.

```sh
# 1. Install Nix (once). Then open a new Terminal window.
curl -fsSL https://install.determinate.systems/nix | sh -s -- install

# 2. Clone this repo (git from Nix, so nothing else is installed).
nix run nixpkgs#git -- clone https://github.com/dawson-shay/nix-config.git ~/repos/nix-config

# 3. User config (Home Manager): Emacs, git, gh (and git using it for GitHub), shell.
nix run home-manager -- switch --flake ~/repos/nix-config#<user>@<host>

# 4. Open a new Terminal window, then log in with the Nix-managed gh. Step 5
#    needs it: #mini imports the private tinytrader-ops.
gh auth login

# 5. Machine config (nix-darwin): hostname, Tailscale, SSH, power, Colima,
#    and the tinytrader-ops role. Asks for your password.
~/repos/nix-config/scripts/switch

# 6. Open a new Terminal window (only new login shells pick up nix-darwin's
#    tools on PATH), then join the tailnet.
sudo tailscale up
```

A new machine needs its own entries in `flake.nix` (`homeConfigurations` and, for a Mac, `darwinConfigurations`), with its username and home directory. If a switch stops because a file already exists, add `-b backup` to move the old file aside.

A Mac that runs part of the tinytrader deployment then needs the sops age key and the tinytrader checkouts: tinytrader-ops' `docs/operations.md`, "Rebuild a host from scratch".

## Package management

Do not install persistent workstation tools imperatively when they should be reproducible.

Shared user tools belong in `home.nix`:

```nix
home.packages = [
  pkgs.tree
  pkgs.somePackage
];
```

Machine-level packages and services belong in the machine config: `/etc/nixos/configuration.nix` on the X200s, `darwin/mini.nix` on the M4.

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

EXWM is installed through Home Manager (on Linux only) and launched on the X200s using:

```elisp
(exwm-wm-mode)
```

The X server itself is enabled at the NixOS system level. EXWM can currently be launched from a TTY with:

```sh
startx ~/.xsession
```

## Git workflow

This repository is backed by GitHub.

Typical change:

```text
edit
→ home-manager switch --flake '.#daws@x200s'   (or scripts/switch for a Mac's machine config)
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

This repository is public: never commit secrets, tokens or keys to it, even encrypted, or private details (addresses, account identifiers, anything from tinytrader-ops beyond the role's name). Secrets live in private repos as sops files (tinytrader-ops) or outside git.

Treat the repository as the source of truth. Avoid manually mutating generated files such as:

```text
~/.config/emacs
~/.config/git/config
~/.cargo/config.toml
```

Edit their source configuration instead, apply the configuration, test it, then commit the result.
