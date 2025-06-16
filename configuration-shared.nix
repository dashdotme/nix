{ pkgs, ... }:
{
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [ "electron-33.4.11" ];
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
