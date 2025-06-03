{ config, pkgs, ... }:

{
  boot.kernelParams = [ "i915.enable_dc=0" ];
}
