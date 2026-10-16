# The Mac mini M4 (nix-darwin): the machine-level configuration. Your user
# setup (git, gh, Emacs, SSH config) stays in Home Manager (home.nix and
# hosts/mac.nix), applied as on every machine.
#
# It's the main desktop and runs research and training jobs. It runs none of
# tinytrader's services (they're on the NAS), so nothing here comes from
# tinytrader-ops.
#
#   first time:  sudo nix run nix-darwin -- switch --flake ~/.config/home-manager#mini
#   after that:  sudo darwin-rebuild switch --flake ~/.config/home-manager#mini
{ pkgs, ... }:
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
  ];

  # On the tailnet as `mini`.
  services.tailscale.enable = true;

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
