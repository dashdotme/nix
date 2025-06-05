{ config, ...}:

{
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

}
