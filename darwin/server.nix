# What the always-on Macs (darwin/mini.nix, darwin/m2.nix) add to
# darwin/common.nix: the container tools, Colima as a boot daemon (sized by
# local.colima), and never sleeping.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  vm = config.local.colima;
in
{
  options.local.colima = {
    cpu = mkOption {
      type = types.ints.positive;
      description = "CPUs for Colima's VM.";
    };
    memory = mkOption {
      type = types.ints.positive;
      description = "Memory for Colima's VM, in GiB.";
    };
    disk = mkOption {
      type = types.ints.positive;
      description = "Colima's VM disk, in GiB (a sparse file: it takes what is used).";
    };
  };

  config = {
    # `docker compose` / `docker buildx`: docker looks for CLI plugins here.
    system.activationScripts.postActivation.text = ''
      mkdir -p /usr/local/libexec/docker/cli-plugins
      ln -sfn ${pkgs.docker-compose}/libexec/docker/cli-plugins/docker-compose \
        /usr/local/libexec/docker/cli-plugins/docker-compose
      ln -sfn ${pkgs.docker-buildx}/libexec/docker/cli-plugins/docker-buildx \
        /usr/local/libexec/docker/cli-plugins/docker-buildx
    '';

    # Containers: Colima runs the Docker engine in a lightweight VM (no
    # Docker Desktop); docker, compose and buildx are the client side.
    # (mkAfter: listed after nix-darwin's own, as when this was in mini.nix.)
    environment.systemPackages = lib.mkAfter (with pkgs; [
      colima
      docker-client
      docker-compose
      docker-buildx
    ]);

    # Colima starts at boot and stays up: a system daemon run as the primary
    # user, so the containers come back after a reboot or power cut without
    # anyone logging in. That needs FileVault off; with it on, nothing starts
    # until the disk is unlocked at the login window. Apple's virtualization
    # (vz) with virtiofs mounts; the home folder is mounted writable so bind
    # mounts from ~/repos (e.g. tinytrader-ops' state/console) work.
    launchd.daemons.colima =
      let
        user = config.system.primaryUser;
        home = "/Users/${user}";
      in
      {
        command = "${pkgs.colima}/bin/colima start --foreground --vm-type vz --mount-type virtiofs --mount ${home}:w --cpu ${toString vm.cpu} --memory ${toString vm.memory} --disk ${toString vm.disk}";
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

    # Long jobs: the computer never sleeps (the display still does), and it
    # comes back after a power cut.
    power.sleep.computer = "never";
    power.restartAfterPowerFailure = true;
  };
}
