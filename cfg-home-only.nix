{ config, ...}:

{
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
    modesetting.enable = true;
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    nvidiaSettings = true;
    open = false;
  };

  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    "processor.max_cstate=1"
    "intel_idle.max_cstate=1"
  ];

}
