# An example NixOS host (nixosConfigurations.example): proof that
# nixos/common.nix evaluates, not a real machine. Its hardware is a stub, as
# a VM's would be; a real host takes its own from nixos-generate-config's
# hardware-configuration.nix.
{ ... }:
{
  imports = [ ./common.nix ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "example";

  # The hardware stub: one disk, BIOS boot.
  fileSystems."/" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };
  boot.loader.grub.device = "/dev/vda";

  users.users.daws = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "docker"
    ];
    # The keys allowed in (public keys only), as on the Macs.
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKAL6Lsp876QwJzwyhOxt4vutaFD0gL8y2q6QiysuNnP daws@macbook-air"
    ];
  };

  # The release this host was first installed with; never change it after.
  system.stateVersion = "26.05";
}
