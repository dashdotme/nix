{ pkgs, ... }:

{

  nix.settings.download-buffer-size = 2147483648;  # 2 GB; to speed up flake bumps

  # Power management
  services.tlp.enable = true;
  # powerManagement.powertop.enable = true; # doesn't seem great

  boot.kernelParams = [
    "i915.enable_dc=0"
    "intel_idle.max_cstate=1"
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
  ];

  services.hardware.bolt.enable = true;
}
