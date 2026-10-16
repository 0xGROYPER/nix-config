# The Mac mini M4 (nix-darwin): the machine-level configuration. Your user
# setup (git, gh, Emacs, SSH config) stays in Home Manager (home.nix and
# hosts/mac.nix), applied as on every machine.
#
# It's the main desktop and runs research and training jobs, and is becoming
# the primary tinytrader host (containers via Colima below). What tinytrader
# runs here is defined in tinytrader-ops, not in this file.
#
#   scripts/switch   (builds as you, so the private tinytrader-ops input can be
#                    fetched with your GitHub login, then activates as root)
{ config, pkgs, lib, ... }:
{
  # The local AI endpoint, a daemon run as you on 127.0.0.1:8317.
  imports = [ ./ai-proxy.nix ];

  # sops-nix (secrets from the private nix-secrets input): decrypt with this
  # Mac's SSH host key, as an age key (its recipient is in nix-secrets'
  # .sops.yaml). Not the RSA host key as a GPG key, sops-nix's other default.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.gnupg.sshKeyPaths = [ ];

  nixpkgs.hostPlatform = "aarch64-darwin";
  system.stateVersion = 6;
  # This Mac's account is still dawsonshay; change to daws after the rename.
  system.primaryUser = "dawsonshay";
  # Determinate Nix manages Nix itself.
  nix.enable = false;
  # Leave the shells' /etc files alone; Home Manager handles your shell.
  programs.zsh.enable = false;
  programs.bash.enable = false;
  # With the shells left alone, nothing puts nix-darwin's tools (darwin-rebuild,
  # tailscale, ...) on PATH; macOS's path_helper adds /etc/paths.d entries for
  # every login shell, and sudo inherits it. path_helper ignores symlinks, so
  # this is written as a plain file rather than through environment.etc.
  system.activationScripts.postActivation.text = ''
    printf '/run/current-system/sw/bin\n' > /etc/paths.d/50-nix-darwin

    # `docker compose` / `docker buildx`: docker looks for CLI plugins here.
    mkdir -p /usr/local/libexec/docker/cli-plugins
    ln -sfn ${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose \
      /usr/local/libexec/docker/cli-plugins/docker-compose
    ln -sfn ${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx \
      /usr/local/libexec/docker/cli-plugins/docker-buildx
  '';

  networking.computerName = "mini";
  networking.hostName = "mini";
  networking.localHostName = "mini";

  # Secrets tools (tinytrader-ops decision 0004: sops files, age keys, and
  # ssh-to-age for host identities), and tmux for long-running jobs.
  environment.systemPackages = with pkgs; [
    age
    jq
    sops
    ssh-to-age
    tmux
    # Containers: Colima runs the Docker engine in a lightweight VM (no
    # Docker Desktop); docker, compose and buildx are the client side.
    colima
    docker-client
    docker-compose
    docker-buildx
  ];

  # Colima starts at boot and stays up: a system daemon run as the primary
  # user, so the containers (the trading services, after the cutover) come
  # back after a reboot or power cut without anyone logging in. That works
  # because FileVault is off; with it on, nothing starts until the disk is
  # unlocked at the login window. Apple's virtualization (vz) with virtiofs
  # mounts; the home folder is mounted writable so bind mounts from ~/repos
  # (e.g. tinytrader-ops' state/console) work.
  launchd.daemons.colima =
    let
      user = config.system.primaryUser;
      home = "/Users/${user}";
    in
    {
      command = "${pkgs.colima}/bin/colima start --foreground --vm-type vz --mount-type virtiofs --mount ${home}:w --cpu 6 --memory 12 --disk 100";
      serviceConfig = {
        UserName = user;
        GroupName = "staff";
        RunAtLoad = true;
        KeepAlive = true;
        EnvironmentVariables = {
          HOME = home;
          USER = user;
          PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
        };
        StandardOutPath = "${home}/Library/Logs/colima.out.log";
        StandardErrorPath = "${home}/Library/Logs/colima.err.log";
      };
    };

  # On the tailnet as `mini`.
  services.tailscale.enable = true;
  # nix-darwin's module links /etc/resolver/ts.net into /etc/static, but
  # tailscaled (1.102+) writes /etc/resolver itself and refuses to follow a
  # symlink out of it ("openat ts.net: path escapes from parent"), so its
  # DNS setup fails. Let tailscaled own the file.
  environment.etc."resolver/ts.net".enable = lib.mkForce false;

  # SSH in from the other machines, by key only.
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
    '';
  };

  # Keep the M2's nightly tinytrader backups here (tinytrader-ops
  # modules/backup-darwin.nix): its backup key, from tinytrader-ops'
  # inventory.nix backup.keys, goes in this user's authorized keys
  # (users.users.<you>.openssh.authorizedKeys), restricted to rrsync,
  # write-only, from the tailnet, into ~/Backups/tinytrader-from-mac-mini-m2
  # (mode 700). Its files are age-encrypted before they leave the M2; no
  # shell, no forwarding, nothing readable back. Needs the sshd above.
  tinytrader-ops.backup.receive = true;

  # Long training runs: the computer never sleeps (the display still does),
  # and it comes back after a power cut.
  power.sleep.computer = "never";
  power.restartAfterPowerFailure = true;
}
