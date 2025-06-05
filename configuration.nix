# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{ config, pkgs, ... }:

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

  # Use the systemd-boot EFI boot loader.
  boot.loader = {
    efi.canTouchEfiVariables = true;
    grub = {
      enable = true;
      useOSProber = true;
      efiSupport = true;
      device = "nodev";
    };
  };

  networking.hostName = "dash_nixos"; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

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

  # Set your time zone.
  time.timeZone = "Australia/Brisbane";

  # Configure network proxy if necessary
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
    vim
    wget
    bluez
    bluez-tools
    usbutils
    udiskie
    # microsoft-edge # this being removed is some terrorist action
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

  # Configure keymap in X11
  # services.xserver.xkb.layout = "us";
  # services.xserver.xkb.options = "eurosign:e,caps:escape";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # hardware.pulseaudio.enable = true;
  # OR
  security.rtkit.enable = true; # scheduling priority service
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
  };

  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.libinput.enable = true;
  programs.zsh.enable = true;

  programs.nix-ld.enable = true; # use dynamically linked binaries

  # Define a user account. Don't forget to set a password with ‘passwd’.
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

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 57621 ]; # spotify
  networking.firewall.allowedUDPPorts = [ 5335 ]; # spotify

  system.stateVersion = "24.11"; # Did you read the comment?

}

