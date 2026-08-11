{ username, ... }:
{
  # VMware's virtual LSI Logic Parallel controller needs this in the initrd.
  boot.initrd.availableKernelModules = [ "mptspi" ];

  virtualisation.vmware.guest.enable = true;

  # Home Manager's Noctalia unit starts through the user service manager, so
  # set the software-rendering variable on the unit explicitly.
  home-manager.users.${username}.systemd.user.services.noctalia.Service.Environment = [
    "LIBGL_ALWAYS_SOFTWARE=1"
  ];
}
