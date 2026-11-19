# QEMU/KVM guest (virt-manager) with virtio-gpu. Use INSTEAD of gpu-amd / gpu-nvidia / gpu-virtualbox.
{ ... }:
{
  flake.modules.nixos.gpu-qemu = { ... }: {
    services.qemuGuest.enable = true;
    services.spice-vdagentd.enable = true;
    boot.initrd.kernelModules = [ "virtio_gpu" ];
    hardware.graphics.enable = true;
    environment.sessionVariables = {
      WLR_NO_HARDWARE_CURSORS = "1";
      WLR_RENDERER_ALLOW_SOFTWARE = "1"; # llvmpipe fallback if virgl/3D is off
    };
  };
}
