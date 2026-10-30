# What every Linux machine here shares at the machine level (NixOS), the
# counterpart of darwin/common.nix, imported by each host's own file (e.g.
# nixos/example.nix), which adds its name, hardware, users and keys. What the
# Macs share too (tools, Tailscale, SSH by key only, sops-nix's key, the
# timezone) is in system/common.nix; this is what's Linux-only:
#
#   Nix with flakes; Ghostty's terminfo; Docker natively (no VM, unlike
#   Colima on the Macs); never sleeps.
#
# Hosts that use it also import sops-nix.nixosModules.sops (flake.nix).
{ pkgs, ... }:
{
  imports = [ ../system/common.nix ];

  # Ghostty's terminfo, so `ssh host` from Ghostty (plain ssh, TERM=xterm-ghostty;
  # hosts/mac.nix) gets a working terminal here. The Macs compile their own copy
  # at each Home Manager switch, for macOS's older ncurses (hosts/mac.nix).
  environment.systemPackages = [ pkgs.ghostty.terminfo ];

  # NixOS manages Nix itself here (on the Macs, Determinate Nix does).
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Containers: the Docker engine as a systemd service, started at boot;
  # docker compose and buildx come with it. Add your user to the docker group
  # in the host's file (users.users.<you>.extraGroups).
  virtualisation.docker.enable = true;

  # Long jobs: the machine never sleeps (the display still blanks). Restarting
  # after a power cut is a firmware (BIOS/UEFI) setting on a PC.
  systemd.targets = {
    sleep.enable = false;
    suspend.enable = false;
    hibernate.enable = false;
    hybrid-sleep.enable = false;
  };
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };
}
