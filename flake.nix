{
  description = "NixOS configuration with Home Manager";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
  let
    mkSystem = modules: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix

        # Custom packages
        {
          nixpkgs.overlays = [
            (final: prev: {
              mojo = prev.callPackage ./packages/mojo.nix {};
            })
          ];
        }

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.users.dash = import ./home.nix;
        }
      ] ++ modules;
    };
  in
  {
    nixosConfigurations = {
      home = mkSystem [
        ./hardware-home.nix
        ./mounts-home.nix
      ];

      xps = mkSystem [
        ./hardware-xps.nix
        ./mounts-xps.nix
        ./xps-only.nix
      ];
    };
  };
}
