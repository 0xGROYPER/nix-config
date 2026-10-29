# What every Mac here shares at the machine level (nix-darwin), imported by
# each Mac's own file (darwin/mini.nix, darwin/m2.nix, darwin/laptop.nix),
# which adds its name, its user and what it alone runs. What Linux shares too
# (tools, Tailscale, SSH by key only, sops-nix's key) is in system/common.nix;
# this is what's Mac-only:
#
#   Nix managed by Determinate Nix; the shells' /etc files left alone (Home
#   Manager owns zsh); nix-darwin's tools on PATH through /etc/paths.d;
#   tailscaled's resolver file.
#
# The always-on Macs add containers, Colima and never sleeping
# (darwin/server.nix).
{ lib, ... }:
{
  imports = [ ../system/common.nix ];

  config = {
    nixpkgs.hostPlatform = "aarch64-darwin";
    system.stateVersion = 6;
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
    '';

    # Tailscale (enabled in system/common.nix): nix-darwin's module links
    # /etc/resolver/ts.net into /etc/static, but tailscaled (1.102+) writes
    # /etc/resolver itself and refuses to follow a symlink out of it ("openat
    # ts.net: path escapes from parent"), so its DNS setup fails. Let tailscaled own the file.
    environment.etc."resolver/ts.net".enable = lib.mkForce false;
  };
}
