{
  description = "My NixOS/MacOS configuration";
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
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = { nixpkgs-linux, nix-darwin, home-manager, nixos-hardware, self, ... }:
  let
    mkNixosSystem = modules: nixpkgs-linux.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration-shared.nix
        ./configuration-linux.nix

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
      specialArgs = { inherit self; };
      modules = [
        ./configuration-shared.nix
        ./configuration-darwin.nix
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
        nixos-hardware.nixosModules.dell-xps-13-9310
        ./hardware-xps.nix
        ./mounts-xps.nix
        ./cfg-xps-only.nix
      ];
    };

    darwinConfigurations = {
      macbook = mkDarwinSystem [
      ];
    };
  };

}
