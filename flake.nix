{
  description = "Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-darwin,
      ...
    }:
    let
      mkHome =
        {
          system,
          username,
          homeDirectory,
          hostModule,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.${system};

          modules = [
            ./home.nix
            hostModule

            {
              home.username = username;
              home.homeDirectory = homeDirectory;
            }
          ];
        };
    in
    {
      homeConfigurations = {
        "daws@x200s" = mkHome {
          system = "x86_64-linux";
          username = "daws";
          homeDirectory = "/home/daws";
          hostModule = ./hosts/x200s.nix;
        };

        # Change to x86_64-darwin later if the Mac is Intel.
        "daws@mac" = mkHome {
          system = "aarch64-darwin";
          username = "daws";
          homeDirectory = "/Users/daws";
          hostModule = ./hosts/mac.nix;
        };

        # The Mac mini M4. Its account is still dawsonshay; once it's renamed
        # to daws, this can go and `daws@mac` applies.
        "dawsonshay@mini" = mkHome {
          system = "aarch64-darwin";
          username = "dawsonshay";
          homeDirectory = "/Users/dawsonshay";
          hostModule = ./hosts/mac.nix;
        };
      };

      # Machine-level configuration for Macs (nix-darwin). User settings stay
      # in homeConfigurations above.
      darwinConfigurations = {
        # The Mac mini M4.
        mini = nix-darwin.lib.darwinSystem {
          modules = [ ./darwin/mini.nix ];
        };
      };
    };
}