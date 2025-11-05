{ pkgs, ... }:
{
  # nix configuration
  nix = {
    package = pkgs.nixVersions.latest;
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  # boot and filesystem
  boot.supportedFilesystems = [ "ntfs" "vfat" "ext4" ];
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;
    "vm.dirty_ratio" = 30;
    "vm.dirty_background_ratio" = 5;
    "vm.vfs_cache_pressure" = 50;
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

  # nix store management
  nix.settings.auto-optimise-store = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  # networking
  networking.networkmanager.enable = true;

  # graphics and hardware
  hardware.graphics = {
    enable = true;
  };
  hardware.enableAllFirmware = true;
  hardware.enableRedistributableFirmware = true;

  # bluetooth
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    package = pkgs.bluez;
  };
  boot.kernelModules = [ "btintel" "btusb" ];
  hardware.firmware = with pkgs; [
    linux-firmware
  ];
  services.dbus.enable = true;
  services.blueman.enable = true;

  # locale and timezone
  time.timeZone = "Australia/Brisbane";
  i18n.defaultLocale = "en_US.UTF-8";

  # tty (minimal boot/recovery terminal) config
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true; # use xkb.options in tty.
  };

  # === desktop environment ===
  # login (display manager)
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

  # compositor (wayland tiling manager)
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    withUWSM = true;
  };

  # x11 and traditional desktop environments
  services.xserver = {
    # if using gnome/kde
    # enable = true;
    #
    # gnome:
    # displayManager.gdm = {
    #   enable = false;
    #   wayland = true;
    # };
    # desktopManager.gnome.enable = false;
    #
    # kde:
    # plasma6.enable = true;

    # keyboard and package exclusions
    xkb.layout = "us";
    xkb.variant = "";
    excludePackages = with pkgs; [ xterm ];
  };

  # wayland app compatibility
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # === desktop environment end ===
  # system packages
  environment.systemPackages = with pkgs; [
    # basic
    kitty
    ghostty
    vim
    python3

    # usbs
    usbutils
    udiskie

    # bluetooth
    bluez
    bluez-tools

    # sound
    alsa-utils

    # sys inspection
    iotop
    htop
    btop
    sysstat
    smartmontools

    # cloud storage manager
    rclone
    onedrive # better caching, works around onedrive rate limits

    # gui apps
    networkmanagerapplet # wifi ui
    spotify # music
    vlc # video
    bitwarden-desktop # pw manager
    google-chrome
    obsidian # markdown
    zathura # pdfs

    # cli utils
    unzip
    wget
    curl
    gnutar
    gzip
    procs
    tree
    eza # better ls/tree

    # hyprland
    hyprlock # lock screen
    waybar # menu bar - duplicated to be explicit; actually managed via programs.waybar in home.nix
    dunst # notifications
    libnotify # dunst dependency
    yazi # tui file manager
    swww # wallpaper
    rofi-wayland # app launcher
    hyprpolkitagent # auth daemon
    sddm-astronaut # login + login themes
    wofi # launcher
    hypridle # idling daemon
    wl-clipboard # wl-copy & wl-paste
    clipse # wl-clipboard - persist text/images, tui
    grim # screenshot
    slurp # select area (for screens)
    satty # annotate screenshot
    feh # shell image viewer

    # waybar deps
    pwvucontrol # sound gui
    wlogout # logout gui
    playerctl # media cli
    pciutils # hardware monitoring

    # games
    lutris
    discord
  ];

  # package configuration
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = [ "electron-33.4.11" ];
    allowUnsupportedSystem = true;
    packageOverrides = pkgs: {
      sddm-astronaut = pkgs.sddm-astronaut.override { embeddedTheme = "japanese_aesthetic"; };
    };
  };

  # sandbox app fixes (electron)
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

  # fonts
  fonts.packages = with pkgs; [
    lexend
    font-awesome
    nerd-fonts.jetbrains-mono
  ];

  # programs
  programs = {
    neovim.enable = true;
    neovim.defaultEditor = true;
    firefox.enable = true;
    zsh.enable = true;
    nix-ld.enable = true; # use dynamically linked binaries
    steam.enable = true;
  };

  # audio
  security.rtkit.enable = true; # scheduling priority service
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;

    extraConfig.pipewire = {
      "10-clock-rate" = {
        "context.properties" = {
          "default.clock.rate" = 48000;
        };
      };
    };
  };

  # misc services
  services = {
    udisks2.enable = true; # auto mounting
    gvfs.enable = true; # auto mounting
    libinput.enable = true; # touchpad support
    openssh.enable = true;
    printing.enable = true;
  };

  # users
  users.users.dash = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "audio" "bluetooth" "docker" "storage" ];
    shell = pkgs.zsh;
  };

  # virtualization
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # firewall
  networking.firewall.allowedTCPPorts = [ 57621 ]; # spotify
  networking.firewall.allowedUDPPorts = [ 5335 ]; # spotify

  # ssd maintenance
  services.fstrim.enable = true;

  # initial nixos version (for compat)
  system.stateVersion = "24.11";

  # voyager keyboard
  services.udev.extraRules = ''
    # Rules for Oryx web flashing and live training
    KERNEL=="hidraw*", ATTRS{idVendor}=="16c0", MODE="0664", GROUP="plugdev"
    KERNEL=="hidraw*", ATTRS{idVendor}=="3297", MODE="0664", GROUP="plugdev"
    # Legacy rules for live training over webusb (Not needed for firmware v21+)
      # Rule for all ZSA keyboards
      SUBSYSTEM=="usb", ATTR{idVendor}=="3297", GROUP="plugdev"
      # Rule for the Moonlander
      SUBSYSTEM=="usb", ATTR{idVendor}=="3297", ATTR{idProduct}=="1969", GROUP="plugdev"
      # Rule for the Ergodox EZ
      SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="1307", GROUP="plugdev"
      # Rule for the Planck EZ
      SUBSYSTEM=="usb", ATTR{idVendor}=="feed", ATTR{idProduct}=="6060", GROUP="plugdev"
    # Wally Flashing rules for the Ergodox EZ
    ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", ENV{ID_MM_DEVICE_IGNORE}="1"
    ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789A]?", ENV{MTP_NO_PROBE}="1"
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789ABCD]?", MODE:="0666"
    KERNEL=="ttyACM*", ATTRS{idVendor}=="16c0", ATTRS{idProduct}=="04[789B]?", MODE:="0666"
    # Keymapp / Wally Flashing rules for the Moonlander and Planck EZ
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0483", ATTRS{idProduct}=="df11", MODE:="0666", SYMLINK+="stm32_dfu"
    # Keymapp Flashing rules for the Voyager
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="3297", MODE:="0666", SYMLINK+="ignition_dfu"
  '';


}
