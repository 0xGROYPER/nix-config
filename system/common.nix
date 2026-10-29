# What every machine here shares at the system level, Mac (nix-darwin) or
# Linux (NixOS). Imported by darwin/common.nix and nixos/common.nix, which add
# what differs by platform (launchd or systemd, PATH, power, containers).
#
#   The system tools; Tailscale; SSH in by key only; sops-nix decrypting with
#   the SSH host key; the timezone (NixOS only, for now: below).
#
# Every option here exists on both platforms, except where guarded by
# isDarwin. Each host's own file lists the keys allowed in, the same way on
# both: users.users.<you>.openssh.authorizedKeys.keys.
{ pkgs, lib, ... }:
let
  inherit (pkgs.stdenv.hostPlatform) isDarwin;
in
{
  # sops-nix (secrets from the private nix-secrets input): decrypt with this
  # machine's SSH host key, as an age key (its recipient is in nix-secrets'
  # .sops.yaml). Not the RSA host key as a GPG key, sops-nix's other default.
  # The key survives a wipe: scripts/host-identity.
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.gnupg.sshKeyPaths = [ ];

  # Secrets tools (tinytrader-ops decision 0004: sops files, age keys, and
  # ssh-to-age for host identities), and tmux for long-running jobs.
  # (mkAfter: listed after the platform's own packages.)
  environment.systemPackages = lib.mkAfter (
    with pkgs;
    [
      age
      jq
      sops
      ssh-to-age
      tmux
    ]
  );

  # Unfree packages, by name only. Nomad (BSL-licensed, so nixpkgs marks it
  # unfree): tinytrader-ops' batch scheduler, a server and client on the mini
  # and later a client on the Linux hosts (its modules/nomad-darwin.nix).
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "nomad" ];

  # On the tailnet, under networking.hostName (join: `sudo tailscale up`).
  services.tailscale.enable = true;

  # SSH in from the other machines, by key only. nix-darwin's sshd takes raw
  # sshd_config lines; NixOS's takes the same settings as options (it would
  # otherwise write PasswordAuthentication yes itself). Keepalives drop a
  # connection whose other end has gone (a laptop asleep or off Wi-Fi) within
  # about 45 s, rather than leaving its emacsclient -t and shells hanging.
  services.openssh = {
    enable = true;
  }
  // (
    if isDarwin then
      {
        extraConfig = ''
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          PermitRootLogin no
          ClientAliveInterval 15
          ClientAliveCountMax 3
        '';
      }
    else
      {
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
          PermitRootLogin = "no";
          ClientAliveInterval = 15;
          ClientAliveCountMax = 3;
        };
      }
  );

  # The Macs keep the timezone set in System Settings (nix-darwin would run
  # systemsetup at every activation); set it there to match.
  time.timeZone = lib.mkIf (!isDarwin) "America/Los_Angeles";
}
