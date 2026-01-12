{ pkgs, ... }:

{

  nix.settings.download-buffer-size = 2147483648; # 2 GB; to speed up flake bumps

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
    deluge-gtk

    # casting eg. to chromecast
    gnome-network-displays
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    gst_all_1.gst-plugins-bad
    gst_all_1.gst-plugins-ugly
    gst_all_1.gst-libav
    gst_all_1.gst-vaapi

    mkcert
    nssTools
    openssl
  ];

  networking.firewall = {
    allowedTCPPorts = [
      8008 # chromecast
      8009 # chromecast
      8096 # jellyfin
    ];
    allowedUDPPorts = [
      5253 # gnome-network-displays
      5353 # gnome-network-displays / mDNS
      7256 # gnome-network-displays
    ];
  };
  services.hardware.bolt.enable = true;
  services.avahi.enable = true;

  system.activationScripts.mkcert-setup = {
    text = ''
      # Set up mkcert CA
      export CAROOT=/var/lib/mkcert
      mkdir -p $CAROOT
      ${pkgs.mkcert}/bin/mkcert -install

      # Generate certs for Caddy - individual domains instead of wildcard
      mkdir -p /var/lib/caddy
      cd /var/lib/caddy
      ${pkgs.mkcert}/bin/mkcert -cert-file local.crt -key-file local.key \
        jellyfin.local \
        radarr.local \
        sonarr.local \
        prowlarr.local \
        transmission.local \
        localhost
      chmod 644 local.crt local.key
    '';
    deps = [ ];
  };
  security.pki.certificateFiles = [ ./certs/mkcert-root.pem ];

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

    transmission = {
      enable = true;
      # vpn.enable = true;
      # peerPort = 50000; # Set this to the port forwarded by your VPN

      extraSettings = {
        rpc-host-whitelist = "transmission.local,localhost";
        rpc-host-whitelist-enabled = true;
      };
    };

    # It is possible for this module to run the *Arrs through a VPN, but it
    # is generally not recommended, as it can cause rate-limiting issues.
    bazarr.enable = true;
    lidarr.enable = true;
    prowlarr.enable = true;
    radarr.enable = true;
    readarr.enable = true;
    sonarr.enable = true;
    jellyseerr.enable = true;
    # sabnzbd.enable = true;

  };

  services.flaresolverr = {
    enable = true;
    port = 8191;
  };

  services.caddy = {
    enable = true;
    virtualHosts = {
      "jellyfin.local".extraConfig = ''
        tls /var/lib/caddy/local.crt /var/lib/caddy/local.key
        reverse_proxy localhost:8096
      '';
      "radarr.local".extraConfig = ''
        tls /var/lib/caddy/local.crt /var/lib/caddy/local.key
        reverse_proxy localhost:7878
      '';
      "sonarr.local".extraConfig = ''
        tls /var/lib/caddy/local.crt /var/lib/caddy/local.key
        reverse_proxy localhost:8989
      '';
      "prowlarr.local".extraConfig = ''
        tls /var/lib/caddy/local.crt /var/lib/caddy/local.key
        reverse_proxy localhost:9696
      '';
      "transmission.local".extraConfig = ''
        tls /var/lib/caddy/local.crt /var/lib/caddy/local.key
        reverse_proxy localhost:9091
      '';
    };
  };

  networking.hosts = {
    "127.0.0.1" = [
      "jellyfin.local"
      "radarr.local"
      "sonarr.local"
      "prowlarr.local"
      "transmission.local"
    ];
  };

}
