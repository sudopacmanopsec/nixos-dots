# VirtualBox guest. Pick this INSTEAD of gpu-amd / gpu-nvidia (never together).
# VM settings: Graphics Controller = VMSVGA, Enable 3D Acceleration, Video Memory 128MB, Enable EFI (optional).
{ ... }:
{
  flake.modules.nixos.gpu-virtualbox = { ... }: {
    virtualisation.virtualbox.guest.enable = true;
    boot.initrd.kernelModules = [ "vmwgfx" ];
    hardware.graphics.enable = true;
    environment.sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1";
      WLR_RENDERER_ALLOW_SOFTWARE = "1"; # fall back to llvmpipe if 3D accel is off
    };
  };
}
