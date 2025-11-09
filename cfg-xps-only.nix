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

  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware
  ];

  # workaround: something is muting speakers at startup
  boot.extraModprobeConfig = ''
    options snd-hda-intel model=dell-headset-multi
  '';

  systemd.user.services.unmute-audio = {
    description = "Ensure audio is unmuted";
    wantedBy = [ "default.target" ];
    after = [ "pipewire.service" "pipewire-pulse.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c 'sleep 2; for i in {1..5}; do ${pkgs.alsa-utils}/bin/amixer -c 0 set Master unmute && ${pkgs.alsa-utils}/bin/amixer -c 0 set Speaker unmute; sleep 10; done'";
    };
  };

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

  networking.hostName = "xps";
  environment.systemPackages = with pkgs; [
    thunderbolt
    torrential
    jellyfin
    stremio

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

  nixarr = {
    enable = true;
    # These two values are also the default, but you can set them to whatever
    # else you want
    # WARNING: Do _not_ set them to `/home/user/whatever`, it will not work!
    mediaDir = "/data/media";
    stateDir = "/data/media/.state/nixarr";

    # vpn = {
    #   enable = true;
    #   # WARNING: This file must _not_ be in the config git directory
    #   # You can usually get this wireguard file from your VPN provider
    #   wgConf = "/data/.secret/wg.conf";
    # };

    jellyfin = {
      enable = true;
      # These options set up a nginx HTTPS reverse proxy, so you can access
      # Jellyfin on your domain with HTTPS
      # expose.https = {
      #   enable = true;
      #   domainName = "mytv.dashdot.me";
      #   acmeMail = "dash@dashdot.me"; # Required for ACME-bot
      # };
    };

    # transmission = {
      # enable = true;
      # vpn.enable = true;
      # peerPort = 50000; # Set this to the port forwarded by your VPN
    # };

    # It is possible for this module to run the *Arrs through a VPN, but it
    # is generally not recommended, as it can cause rate-limiting issues.
    # bazarr.enable = true;
    # lidarr.enable = true;
    # prowlarr.enable = true;
    # radarr.enable = true;
    # readarr.enable = true;
    # sonarr.enable = true;
    # jellyseerr.enable = true;
    # sabnzbd.enable = true;
  };

}
