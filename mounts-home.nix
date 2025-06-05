{ ... }:

{
  fileSystems."/mnt/ubuntu" = {
    device = "/dev/disk/by-uuid/8ce5f10e-7c0a-4554-8201-4e9d6d6ba227";
    fsType = "ext4";
  };

  fileSystems."/mnt/windows" = {
    device = "/dev/disk/by-uuid/AC1EA2231EA1E714";
    fsType = "ntfs";
    options = [ "rw" "uid=1000" "gid=100" "dmask=027" "fmask=137" ];
  };

  fileSystems."/mnt/ntfs-drive" = {
    device = "/dev/disk/by-uuid/CC2E06912E0674AC";
    fsType = "ntfs";
    options = [ "rw" "uid=1000" "gid=100" "dmask=027" "fmask=137" ];
  };

  fileSystems."/mnt/ssd" = {
    device = "/dev/disk/by-uuid/2C8A3ECA8A3E8FF6";
    fsType = "ntfs";
    options = [ "rw" "uid=1000" "gid=100" "dmask=027" "fmask=137" ];
  };

  fileSystems."/mnt/storage" = {
    device = "/dev/disk/by-uuid/2A1217741217446B";
    fsType = "ntfs";
    options = [ "rw" "uid=1000" "gid=100" "dmask=027" "fmask=137" ];
  };
}
