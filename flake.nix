{
  description = "My machines: Home Manager everywhere, nix-darwin for the Macs";

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

    # The tinytrader deployment (private): the roles machines play in it.
    # Building a host that imports one needs GitHub access to that repo.
    tinytrader-ops = {
      url = "git+https://github.com/dawson-shay/tinytrader-ops?ref=main";
      inputs.nix-darwin.follows = "nix-darwin";
    };
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      nix-darwin,
      tinytrader-ops,
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
          modules = [
            ./darwin/mini.nix
            # Its part in tinytrader: what of it runs here natively.
            tinytrader-ops.darwinModules.mini
          ];
        };
      };
    };
}