{ pkgs, ... }:

{

  nix.settings.download-buffer-size = 2147483648;  # 2 GB; to speed up flake bumps

  # Power management
  services.tlp.enable = true;
  # powerManagement.powertop.enable = true; # doesn't seem great

  boot.kernelParams = [
    "i915.enable_dc=0"
    # "intel_idle.max_cstate=1"
  ];

  boot.kernelModules = [ "btintel" "btusb" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.enableAllFirmware = true;
  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware
  ];

  # correct default audio profile - defaults to pro-audio
  services.pipewire.wireplumber.extraConfig."xps-audio-profile" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "device.name" = "alsa_card.pci-0000_00_1f.3-platform-skl_hda_dsp_generic"; }
        ];
        actions = {
          update-props = {
            "device.profile" = "HiFi (HDMI1, HDMI2, HDMI3, Headset, Mic1, Speaker)";
          };
        };
      }
    ];
  };

  systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

  networking.hostName = "framework";
  environment.systemPackages = with pkgs; [
    thunderbolt

    # casting eg. to chromecast
    gnome-network-displays
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gst_all_1.gst-vaapi
  ];

  networking.firewall = {
    allowedTCPPorts = [
      8008   # chromecast
      8009   # chromecast
      8096   # jellyfin
    ];
    allowedUDPPorts = [
      5253   # gnome-network-displays
      5353   # gnome-network-displays / mDNS
      7256   # gnome-network-displays
    ];
  };
  services.hardware.bolt.enable = true;
  services.avahi.enable = true;
}
