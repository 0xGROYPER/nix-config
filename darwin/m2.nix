# The Mac mini M2 (nix-darwin): the machine-level configuration, as
# darwin/mini.nix is the M4's. Its user setup is Home Manager's
# `daws@mac` (home.nix and hosts/mac.nix), as on any Mac whose account is daws.
#
# It's the NAS and job runner until the real NAS: the store and its external
# data drives, research (a container, under Colima), alpaca-history,
# node_exporter, and the mini's off-host backups. What of tinytrader runs
# here is tinytrader-ops' role (darwinModules.mac-mini-m2), not this file.
#
#   scripts/switch m2   (on the M2: builds as you, then activates as root)
#
# Rebuilding it from scratch keeping its identity (SSH host key, Tailscale
# name and address): README, "Rebuilding an existing host".
{ ... }:
{
  imports = [
    # As on the mini: Tailscale, SSH by key only, tools on PATH, sops-nix's
    # key (darwin/common.nix and system/common.nix); Colima and never
    # sleeping (darwin/server.nix).
    ./common.nix
    ./server.nix
  ];

  system.primaryUser = "daws";

  # Its tailnet name follows the hostname.
  networking.computerName = "Dawson’s Mac mini";
  networking.hostName = "dawsons-mac-mini";
  networking.localHostName = "dawsons-mac-mini";

  # Colima's VM, for research (JupyterLab) and the queue's jobs: half of this
  # Mac's 8 cores and 8 GB, leaving the rest to the native store and its
  # drives. FileVault is on here, so Colima (like every boot daemon) starts
  # once the disk is unlocked at the login window, not at power-on.
  local.colima = {
    cpu = 4;
    memory = 4;
    disk = 60;
  };

  # The keys allowed in (public keys only; the backup module adds the mini's
  # backup key, restricted to rrsync).
  users.users.daws.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKAL6Lsp876QwJzwyhOxt4vutaFD0gL8y2q6QiysuNnP daws@macbook-air"
    # The mini's (dawsonshay's ~/.ssh/id_ed25519).
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN8g+NEcHo3csMXIOGGQ220By77YvHC/2sJ9wH/R45eG claude@dawsons-mac-mini-1"
  ];

  # Keep the mini's nightly tinytrader backups here (tinytrader-ops
  # modules/backup-darwin.nix): its backup key may run only rrsync,
  # write-only, from the tailnet, into ~/Backups/tinytrader-from-mini.
  tinytrader-ops.backup.receive = true;

  # The M4 builds this Mac's Home Manager generations and copies them here
  # (nix-config's scripts/switch-home), so daws may add store paths without
  # signatures. A trusted Nix user is root-equivalent; daws is an admin
  # already. Determinate Nix includes this file from /etc/nix/nix.conf; the
  # hash is the installer's version, which this replaces. The daemon reads it
  # when it starts: sudo launchctl kickstart -k system/systems.determinate.nix-daemon
  environment.etc."nix/nix.custom.conf" = {
    text = "extra-trusted-users = daws\n";
    knownSha256Hashes = [ "3bd68ef979a42070a44f8d82c205cfd8e8cca425d91253ec2c10a88179bb34aa" ];
  };
}
