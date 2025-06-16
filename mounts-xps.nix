{ ... }:

{

  fileSystems."/mnt/windows" = {
      device = "/dev/disk/by-uuid/E69865D99865A8AF";
      fsType = "ntfs-3g";
      options = [
        "uid=1000"
        "gid=100"
        "dmask=022"     # 755
        "fmask=133"     # 533 | 644
        "windows_names" # magic for windows compat
        "noauto"        # don't auto-mount at boot
        "user"          # allow user mounting
        "nofail"        # don't fail boot if mount fails
        "x-systemd.automount"  # auto-mount on access
        "x-systemd.device-timeout=10"  # fail fast
      ];
    };

}
