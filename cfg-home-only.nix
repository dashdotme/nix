{ config, ...}:

{

  nix.settings.download-buffer-size = 4294967296; # 4 GB; to speed up flake bumps

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    open = false;
  };

  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "processor.max_cstate=1"
    "intel_idle.max_cstate=1"
  ];

  systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

  systemd.services."systemd-suspend" = {
    serviceConfig = {
      Environment=''"SYSTEMD_SLEEP_FREEZE_USER_SESSIONS=false"'';
    };
  };

  networking.hostName = "home_desktop";

  # self-hosted GitHub Actions runners (`runs-on: kinbots`) for flo_tracker
  services.arcRunners = {
    enable = true;
    githubConfigUrl = "https://github.com/dashdotme/flo_tracker";
    scaleSetName = "kinbots";
    maxRunners = 2;
    githubTokenFile = "/var/lib/secrets/kinbots/github-token";
    # / is nearly full; dedicated partition, see mounts-home.nix
    storageDir = "/mnt/kinbots";
    cache.maxSizeGB = 20;
  };

}
