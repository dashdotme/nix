{ config, pkgs, ... }:

{
  powerManagement.powertop.enable = true;

  boot.kernelParams = [
    "i915.enable_dc=0"
    "intel_idle.max_cstate=1"
  ];

  boot.kernelModules = [ "btintel" "btusb" "snd_soc_sof_pci_intel_tgl"];

}
