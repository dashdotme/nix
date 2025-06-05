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
        "noauto"        # Don't auto-mount at boot
        "user"          # Allow user mounting
        "nofail"        # Don't fail boot if mount fails
        "x-systemd.automount"  # Auto-mount on access instead
        "x-systemd.device-timeout=10"  # Timeout quickly
      ];
    };

}
