{ lib, modulesPath, ... }:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  # 通用 PC 启动模块。安装后可用 nixos-generate-config 生成的硬件设置按需补充。
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "ahci" "usb_storage" "sd_mod" ];
  # AMDGPU 早期 KMS，避免 Wayland/Hyprland 启动时切换显示模式。
  boot.initrd.kernelModules = [ "amdgpu" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware = {
    enableRedistributableFirmware = true;

    # 自动将 amd-ucode 加入启动 initrd，并在启动早期加载微码。
    cpu.amd.updateMicrocode = lib.mkDefault true;

    # Mesa 提供 AMDGPU 所需的 OpenGL 与 Vulkan 用户空间驱动。
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
}
