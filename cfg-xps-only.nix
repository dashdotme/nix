{ pkgs, ... }:

{

  nix.settings.download-buffer-size = 2147483648;  # 2 GB; to speed up flake bumps

  powerManagement.powertop.enable = true;

  boot.kernelParams = [
    "i915.enable_dc=0"
    "intel_idle.max_cstate=1"
  ];

  boot.kernelModules = [ "btintel" "btusb" ];

  # workaround: something is muting speakers at startup
  boot.extraModprobeConfig = ''
    options snd-hda-intel model=dell-headset-multi
  '';


  hardware.firmware = with pkgs; [
    linux-firmware
    sof-firmware
  ];

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

  systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

  networking.hostName = "xps";
  environment.systemPackages = with pkgs; [
    thunderbolt
  ];

  services.hardware.bolt.enable = true;
}
