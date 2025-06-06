# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ pkgs, ... }:

{
  imports =
    [
    ];

  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 30;
    "vm.dirty_background_ratio" = 5;
    "vm.vfs_cache_pressure" = 50;
  };

  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = ["electron-33.4.11"];
    allowUnsupportedSystem = true;
    packageOverrides = pkgs: {
      sddm-astronaut = pkgs.sddm-astronaut.override { embeddedTheme = "purple_leaves"; };
    };
  };

  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      useOSProber = true;
      efiSupport = true;
      device = "nodev";
    };
  };

  networking.networkmanager.enable = true;

  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez;
  };

  # explicit includes to get bluetooth registering
  boot.kernelModules = [ "btintel" "btusb" ];

  hardware.firmware = with pkgs; [
    linux-firmware
  ];
  services.dbus.enable = true;
  services.blueman.enable = true;

  time.timeZone = "Australia/Brisbane";

  # network proxy
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    # keyMap = "us";
    useXkbConfig = true; # use xkb.options in tty.
  };

  # UI/Display Manager
  services.xserver = {
    enable = true;
    displayManager.gdm = {
      enable = false;
      wayland = true;
    };
    desktopManager.gnome.enable = false;
    xkb.layout = "us";
    xkb.variant = "";
    excludePackages = with pkgs; [ xterm ];
  };

  services.displayManager.sddm = {
    wayland.enable = true;
    enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "sddm-astronaut-theme";
    extraPackages = with pkgs; [
      kdePackages.qtsvg
      kdePackages.qtmultimedia
      kdePackages.qtvirtualkeyboard
    ];
  };

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  hardware.graphics = {
    enable = true;
  };

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  # Packages
  environment.systemPackages = with pkgs; [
    kitty
    ghostty
    zellij
    vim
    wget
    bluez
    bluez-tools
    usbutils
    udiskie
    google-chrome
    python3
    iotop
    htop
    btop
    sysstat
    smartmontools

    spotify
    vlc
    bitwarden-desktop

    unzip
    wget
    curl
    gnutar
    gzip
    networkmanagerapplet
    procs

    # hyprland
    hyprlock
    waybar # menu bar
    dunst # notifications
    libnotify # dunst dependency
    yazi # tui file manager
    swww # wallpaper
    rofi-wayland # app launcher
    hyprpolkitagent # auth daemon
    # lxqt.lxqt-policykit # ugly auth daemon
    sddm-astronaut
    wofi
    hypridle

    wl-clipboard # wl-copy & wl-paste
    clipse # wl-clipboard - persist text/images, tui
    grim # screenshot
    slurp # select area (for screens)
    satty # annotate screenshot
    pciutils

    # compat
    # qt6.qtwayland

    # waybar deps
    pavucontrol
    pwvucontrol
    wlogout
    playerctl
    feh

  ];

  fonts.packages = with pkgs; [
    lexend
    font-awesome
    nerd-fonts.jetbrains-mono
  ];

  services.printing.enable = true;

  # sound
  security.rtkit.enable = true; # scheduling priority service
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  # auto mounting services
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  programs.zsh.enable = true;

  programs.nix-ld.enable = true; # use dynamically linked binaries

  users.users.dash = {
     isNormalUser = true;
     extraGroups = [ "wheel" "networkmanager" "audio" "bluetooth" "docker" "storage"]; # Enable ‘sudo’ for the user.
     shell = pkgs.zsh;
     packages = with pkgs; [
       tree
     ];
  };

  boot.supportedFilesystems = [ "ntfs" "vfat" "ext4" ];

  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  programs.firefox.enable = true;
  services.openssh.enable = true;

  networking.firewall.allowedTCPPorts = [ 57621 ]; # spotify
  networking.firewall.allowedUDPPorts = [ 5335 ]; # spotify

  system.stateVersion = "24.11";

}

