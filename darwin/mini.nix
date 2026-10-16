# The Mac mini M4 (nix-darwin): the machine-level configuration. Your user
# setup (git, gh, Emacs, SSH config) stays in Home Manager (home.nix and
# hosts/mac.nix), applied as on every machine.
#
# It's the main desktop and runs research and training jobs, and is becoming
# the primary tinytrader host (containers via Colima below). What tinytrader
# runs here is defined in tinytrader-ops, not in this file.
#
#   first time:  sudo nix run nix-darwin -- switch --flake ~/repos/nix-config#mini
#   after that:  sudo darwin-rebuild switch --flake ~/repos/nix-config#mini
{ pkgs, lib, ... }:
{
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

  # Colima starts at login and stays up. Apple's virtualization (vz) with
  # virtiofs mounts; the home folder is mounted writable so bind mounts from
  # ~/repos (e.g. tinytrader-ops' state/console) work.
  launchd.user.agents.colima = {
    command = "${pkgs.colima}/bin/colima start --foreground --vm-type vz --mount-type virtiofs --mount $HOME:w --cpu 4 --memory 8 --disk 100";
    serviceConfig = {
      RunAtLoad = true;
      KeepAlive = true;
      EnvironmentVariables.PATH = "/run/current-system/sw/bin:/usr/bin:/bin:/usr/sbin:/sbin";
      StandardOutPath = "/tmp/colima.out.log";
      StandardErrorPath = "/tmp/colima.err.log";
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

  # Long training runs: the computer never sleeps (the display still does),
  # and it comes back after a power cut.
  power.sleep.computer = "never";
  power.restartAfterPowerFailure = true;
}
