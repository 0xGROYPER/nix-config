# The MacBook Air's machine config: a client, so darwin/common.nix without
# darwin/server.nix (no containers; it sleeps).
{ lib, ... }:
{
  imports = [ ./common.nix ];

  system.primaryUser = "daws";
  # Its names stay as macOS has them (its tailnet name, dawsons-macbook-air-2,
  # follows them); scripts/switch checks this one.
  networking.localHostName = "Dawsons-MacBook-Air";

  # Tailscale here is the Tailscale app (its network extension), signed in
  # and in the tailnet; nix-darwin's tailscaled beside it would be a second
  # daemon fighting it for the network.
  services.tailscale.enable = lib.mkForce false;

  # On mains power it never sleeps (the display still does), so ssh and
  # Emacs sessions to the M4 aren't cut every minute; on battery macOS's
  # own setting stands. nix-darwin's power.sleep sets both, so this is pmset
  # for AC only, applied at each switch.
  system.activationScripts.postActivation.text = lib.mkAfter ''
    /usr/bin/pmset -c sleep 0
  '';

  # sudo in a terminal here takes Touch ID (in a tmux too). Not over ssh:
  # the sensor is only for sudo on the Mac in front of you.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  # The M4's key, so it can reach this Mac (nix-config's scripts/switch-home).
  users.users.daws.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIN8g+NEcHo3csMXIOGGQ220By77YvHC/2sJ9wH/R45eG claude@dawsons-mac-mini-1"
  ];

  # The M4 builds this Mac's Home Manager generations and copies them here
  # (scripts/switch-home), so daws may add store paths without signatures,
  # as on the M2 (darwin/m2.nix says more).
  environment.etc."nix/nix.custom.conf" = {
    text = "extra-trusted-users = daws\n";
    knownSha256Hashes = [ "3bd68ef979a42070a44f8d82c205cfd8e8cca425d91253ec2c10a88179bb34aa" ];
  };
}
