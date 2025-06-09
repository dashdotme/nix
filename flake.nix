{
  description = "My NixOS/MacOS configuration using home manager";
  inputs = {
    nixpkgs-linux.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-macos.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs-macos";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs-linux";
    };
  };

  outputs = { nixpkgs-linux, nixpkgs-macos, nix-darwin, home-manager, self, ... }:
  let
    mkNixosSystem = modules: nixpkgs-linux.lib.nixosSystem {
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

    mkDarwinSystem = modules: nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = { inherit self; };  # Make self available to all modules
      modules = [
        ./configuration-darwin.nix
        # home-manager.darwinModules.home-manager
        # {
        #   home-manager.useGlobalPkgs = true;
        #   home-manager.useUserPackages = true;
        #   home-manager.backupFileExtension = "backup";
        #   home-manager.users.dash = import ./home-darwin.nix;
        # }
      ] ++ modules;
    };
  in
  {

    nixosConfigurations = {
      home = mkNixosSystem [
        ./hardware-home.nix
        ./mounts-home.nix
        ./cfg-home-only.nix
      ];

      xps = mkNixosSystem [
        ./hardware-xps.nix
        ./mounts-xps.nix
        ./cfg-xps-only.nix
      ];
    };

    darwinConfigurations = {
      macbook = mkDarwinSystem [
        # todo
        # ./cfg-macbook.nix
      ];
    };
  };

}
