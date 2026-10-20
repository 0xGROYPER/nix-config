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
├── flake.lock         pins nixpkgs, Home Manager, nix-darwin, sops-nix, tinytrader-ops and nix-secrets
├── home.nix           user config shared by every machine
├── hosts/
│   ├── x200s.nix      user config for the X200s, including launching EXWM
│   └── mac.nix        macOS user settings (Home Manager owns zsh)
├── darwin/
│   ├── mini.nix       the Mac mini M4's machine config (nix-darwin)
│   └── ai-proxy.nix   the local AI endpoint, a daemon on mini
├── pkgs/
│   ├── ai-proxy.nix   the endpoint: CLIProxyAPI in front of OpenRouter (packages.<system>.ai-proxy)
│   └── cliproxyapi.nix  CLIProxyAPI's release binary, pinned by checksum
├── scripts/
│   ├── switch         apply a Mac's nix-darwin config
│   ├── ai-login       sign the AI endpoint in to a subscription
│   ├── ai-key         set its keys (in nix-secrets)
│   └── ai-client-key  print the key its clients send
├── ssh/config         ~/.ssh/config
└── emacs/
    ├── init.el
    └── early-init.el
```

Responsibilities:

* `/etc/nixos/configuration.nix`: machine/system configuration on the X200s: kernel, bootloader, networking, Xorg, services, hardware.
* `home.nix`: user configuration shared across machines: CLI tools, Git/GitHub, Emacs and Emacs packages, SSH config, and `~/.cargo/config.toml`, which points every checkout's Rust builds at one folder (`~/.cache/cargo-target`) so worktrees don't each leave a `target/` behind.
* `hosts/x200s.nix`, `hosts/mac.nix`: per-platform user settings.
* `darwin/mini.nix`: the Mac mini M4's machine configuration (nix-darwin), the Mac counterpart of `/etc/nixos/configuration.nix`: hostname, Tailscale, SSH (keys only), power (never sleeps, restarts after a power cut), system tools, and Colima, which runs the Docker engine as a boot daemon (`org.nixos.colima`), so containers come back after a reboot without anyone logging in. It also runs the local AI endpoint (`darwin/ai-proxy.nix`, below) and decrypts its secrets with sops-nix.
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
tinytrader-ops input (nor nix-secrets).

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

## Secrets: nix-secrets and sops-nix

Secrets live in a separate private repository,
[nix-secrets](https://github.com/dawson-shay/nix-secrets), as sops files
encrypted to age keys: the operator key (yours, in
`~/Library/Application Support/sops/age/keys.txt`), the offline recovery key,
and each machine's SSH host key (`ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`).
Its README says how to add a secret or a machine. This repository takes it as
the `nix-secrets` flake input (pinned in `flake.lock`, private like
tinytrader-ops, so building `#mini` needs your GitHub login) and names the
files it uses; it never holds a secret, not even encrypted.

[sops-nix](https://github.com/Mic92/sops-nix)'s nix-darwin module decrypts
them on the machine as root, with the host key, so your key isn't needed: at
each activation (the end of `scripts/switch`) and at every boot (its
`org.nixos.sops-install-secrets` daemon, since `/run` is emptied at boot),
into `/run/secrets/<name>`, with the owner and mode `sops.secrets` sets.
Notes:

* It works with `nix.enable = false` (Determinate Nix manages Nix): the
  module doesn't touch `nix.*`; no workaround needed.
* `/run` is `/private/var/run` on the system disk (macOS has no ramfs, so
  `useTmpfs` is off): the decrypted files are on disk, readable by their
  owner and root, until the next boot or activation replaces them.
* `darwin/mini.nix` sets the key sources: the ed25519 host key as an age key,
  and no GPG keys (sops-nix would otherwise also import the RSA host key).
* Secrets are installed after launchd services are (re)loaded, so a daemon
  that reads one waits for it (as `darwin/ai-proxy.nix` does), and a daemon
  isn't restarted when only a secret changes: restart it by hand.

To take a change from nix-secrets: `nix flake update nix-secrets`, commit,
`scripts/switch`.

## The local AI endpoint (ai-proxy)

`darwin/ai-proxy.nix` runs `pkgs/ai-proxy.nix` on mini as a boot-time daemon
(`org.nixos.ai-proxy`) run as you: an OpenAI/Anthropic/Gemini-compatible
endpoint on `http://127.0.0.1:8317/v1` (loopback only), CLIProxyAPI in front
of OpenRouter's free models (the `free` and `free-pool` aliases) plus any
subscriptions signed in with `scripts/ai-login`. Its users are my own tools
(gptel, Pi, ...); nothing in tinytrader uses it.

* Keys: nix-secrets' `ai-proxy.env` (`OPENROUTER_API_KEY`, `AI_PROXY_KEY`),
  at `/run/secrets/ai-proxy.env`, readable only by you.
* State: `~/.local/state/ai-proxy` (mode 700): `config.yaml`, rendered at
  each start with the keys in it (mode 600), and `auth/`, the OAuth sign-ins.
  Not in any backup: if it's lost, sign in again.
* Logs: `~/Library/Logs/ai-proxy.{out,err}.log`.

```sh
scripts/ai-client-key            # the key clients send (as a Bearer token or x-api-key)
curl -s http://127.0.0.1:8317/v1/models -H "Authorization: Bearer $(scripts/ai-client-key)"
scripts/ai-login claude          # or chatgpt, chatgpt-code, gemini; picked up live
scripts/ai-key                   # new OpenRouter key and client key, into ~/repos/nix-secrets
sudo launchctl kickstart -k system/org.nixos.ai-proxy   # restart, e.g. after new keys
nix run .#ai-proxy               # by hand, anywhere (set its environment: pkgs/ai-proxy.nix)
```

It was tinytrader's `nix/ai-proxy.nix`, run as a container by tinytrader-ops,
until 2026-10.

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

Before step 3, move aside what would shadow or fight the managed config (to `~/.local/share/pre-nix-backup/`, not deleted): `~/.emacs.d` (Emacs ignores the managed `~/.config/emacs` while it exists, silently), and any hand-written `~/.zshrc` and `~/.ssh/config` (keep a copy of any host aliases worth adding to `ssh/config` here). Homebrew can stay, but `brew uninstall` what Nix now provides (gh, git, emacs) so only one is on PATH.

A Mac that runs part of the tinytrader deployment then needs the sops age key and the tinytrader checkouts: tinytrader-ops' `docs/operations.md`, "Rebuild a host from scratch".

### Spotlight (by hand)

Keep Spotlight on (turning it off breaks app launching and Finder and Mail search), but keep it out of folders that churn: its index reached 13 GB on the M2 from repos and caches. Its exclusion list is a root-only system file, so it isn't managed here. In System Settings → Spotlight → Search Privacy, add:

- `~/repos`, `~/.cache`, `~/.cargo`, `~/.rustup`, `~/.colima`
- `~/Library/Containers/com.docker.docker` (Docker Desktop, where installed)
- `/nix`

For market-data drives, turn indexing off on the drive itself, which survives unplugging better than a Search Privacy entry: `sudo mdutil -i off /Volumes/<drive>`. Note here whatever goes wrong next time Spotlight misbehaves, so the fix can target it.

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

This repository is public: never commit secrets, tokens or keys to it, even encrypted, or private details (addresses, account identifiers, anything from tinytrader-ops beyond the role's name). Secrets live in private repos as sops files (nix-secrets for the machines, tinytrader-ops for the deployment) or outside git.

Treat the repository as the source of truth. Avoid manually mutating generated files such as:

```text
~/.config/emacs
~/.config/git/config
~/.cargo/config.toml
```

Edit their source configuration instead, apply the configuration, test it, then commit the result.
