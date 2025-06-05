{ ... }:

{

  powerManagement.powertop.enable = true;

  boot.kernelParams = [
    "i915.enable_dc=0"
    "intel_idle.max_cstate=1"
  ];

  boot.kernelModules = [ "btintel" "btusb" "snd_soc_sof_pci_intel_tgl"];

  systemd.services.systemd-suspend.environment.SYSTEMD_SLEEP_FREEZE_USER_SESSIONS = "false";

  networking.hostName = "xps";

}
