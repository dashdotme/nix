{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.mediaServer;
in
{
  options.services.mediaServer = {
    enable = mkEnableOption "media server with nixarr";

    mediaDir = mkOption {
      type = types.str;
      default = "/data/media";
      description = "Directory for media files";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/data/media/.state/nixarr";
      description = "Directory for nixarr state";
    };

    localDomain = {
      enable = mkEnableOption "local domain access with mkcert certificates";

      baseDomain = mkOption {
        type = types.str;
        default = "local";
        description = "Base domain for services (e.g., 'local' for jellyfin.local)";
      };

      certificateFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to mkcert root certificate PEM file";
      };
    };

    services = {
      jellyfin.enable = mkEnableOption "Jellyfin media server";
      transmission.enable = mkEnableOption "Transmission torrent client";
      bazarr.enable = mkEnableOption "Bazarr subtitle manager";
      lidarr.enable = mkEnableOption "Lidarr music manager";
      prowlarr.enable = mkEnableOption "Prowlarr indexer manager";
      radarr.enable = mkEnableOption "Radarr movie manager";
      readarr.enable = mkEnableOption "Readarr book manager";
      sonarr.enable = mkEnableOption "Sonarr TV manager";
      jellyseerr.enable = mkEnableOption "Jellyseerr request manager";
      flaresolverr.enable = mkEnableOption "FlareSolverr CAPTCHA solver";
    };

    transmission = {
      extraSettings = mkOption {
        type = types.attrs;
        default = {};
        description = "Extra settings for Transmission";
      };
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = mkIf cfg.localDomain.enable (with pkgs; [
      mkcert
      nssTools
      openssl
    ]);

    system.activationScripts.mkcert-setup = mkIf cfg.localDomain.enable {
      text = ''
        export CAROOT=/var/lib/mkcert
        mkdir -p $CAROOT
        ${pkgs.mkcert}/bin/mkcert -install

        mkdir -p /var/lib/caddy
        cd /var/lib/caddy
        ${pkgs.mkcert}/bin/mkcert -cert-file local.crt -key-file local.key \
          ${optionalString cfg.services.jellyfin.enable "jellyfin.${cfg.localDomain.baseDomain} \\\n          "}\
          ${optionalString cfg.services.radarr.enable "radarr.${cfg.localDomain.baseDomain} \\\n          "}\
          ${optionalString cfg.services.sonarr.enable "sonarr.${cfg.localDomain.baseDomain} \\\n          "}\
          ${optionalString cfg.services.prowlarr.enable "prowlarr.${cfg.localDomain.baseDomain} \\\n          "}\
          ${optionalString cfg.services.transmission.enable "transmission.${cfg.localDomain.baseDomain} \\\n          "}\
          localhost
        chmod 644 local.crt local.key
      '';
      deps = [ ];
    };

    security.pki.certificateFiles = mkIf (cfg.localDomain.enable && cfg.localDomain.certificateFile != null) [
      cfg.localDomain.certificateFile
    ];

    nixarr = {
      enable = true;
      mediaDir = cfg.mediaDir;
      stateDir = cfg.stateDir;

      jellyfin.enable = cfg.services.jellyfin.enable;

      transmission = mkIf cfg.services.transmission.enable {
        enable = true;
        extraSettings = cfg.transmission.extraSettings;
      };

      bazarr.enable = cfg.services.bazarr.enable;
      lidarr.enable = cfg.services.lidarr.enable;
      prowlarr.enable = cfg.services.prowlarr.enable;
      radarr.enable = cfg.services.radarr.enable;
      readarr.enable = cfg.services.readarr.enable;
      sonarr.enable = cfg.services.sonarr.enable;
      jellyseerr.enable = cfg.services.jellyseerr.enable;
    };

    services.flaresolverr = mkIf cfg.services.flaresolverr.enable {
      enable = true;
      port = 8191;
    };

    services.caddy = mkIf cfg.localDomain.enable {
      enable = true;
      virtualHosts = mkMerge [
        (mkIf cfg.services.jellyfin.enable {
          "jellyfin.${cfg.localDomain.baseDomain}".extraConfig = ''
            tls /var/lib/caddy/local.crt /var/lib/caddy/local.key
            reverse_proxy localhost:8096
          '';
        })
        (mkIf cfg.services.radarr.enable {
          "radarr.${cfg.localDomain.baseDomain}".extraConfig = ''
            tls /var/lib/caddy/local.crt /var/lib/caddy/local.key
            reverse_proxy localhost:7878
          '';
        })
        (mkIf cfg.services.sonarr.enable {
          "sonarr.${cfg.localDomain.baseDomain}".extraConfig = ''
            tls /var/lib/caddy/local.crt /var/lib/caddy/local.key
            reverse_proxy localhost:8989
          '';
        })
        (mkIf cfg.services.prowlarr.enable {
          "prowlarr.${cfg.localDomain.baseDomain}".extraConfig = ''
            tls /var/lib/caddy/local.crt /var/lib/caddy/local.key
            reverse_proxy localhost:9696
          '';
        })
        (mkIf cfg.services.transmission.enable {
          "transmission.${cfg.localDomain.baseDomain}".extraConfig = ''
            tls /var/lib/caddy/local.crt /var/lib/caddy/local.key
            reverse_proxy localhost:9091
          '';
        })
      ];
    };

    networking.hosts = mkIf cfg.localDomain.enable {
      "127.0.0.1" = mkMerge [
        (mkIf cfg.services.jellyfin.enable [ "jellyfin.${cfg.localDomain.baseDomain}" ])
        (mkIf cfg.services.radarr.enable [ "radarr.${cfg.localDomain.baseDomain}" ])
        (mkIf cfg.services.sonarr.enable [ "sonarr.${cfg.localDomain.baseDomain}" ])
        (mkIf cfg.services.prowlarr.enable [ "prowlarr.${cfg.localDomain.baseDomain}" ])
        (mkIf cfg.services.transmission.enable [ "transmission.${cfg.localDomain.baseDomain}" ])
      ];
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.services.jellyfin.enable [ 8096 ];
  };
}
