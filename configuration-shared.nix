{ pkgs, ... }:
{
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [ "electron-39.8.10" ];
  };

  environment.systemPackages = with pkgs; [
    curl
    wget
    tree
    eza
    htop
    btop
    rclone
  ];
}
