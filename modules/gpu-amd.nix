# AMD integrated graphics (amdgpu + mesa). Pick this OR gpu-nvidia per host, never both.
{ ... }:
{
  flake.modules.nixos.gpu-amd = { pkgs, ... }: {
    services.xserver.videoDrivers = [ "amdgpu" ];
    hardware.amdgpu.initrd.enable = true;
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };
    environment.sessionVariables.LIBVA_DRIVER_NAME = "radeonsi";
    environment.systemPackages = with pkgs; [ vulkan-tools radeontop ];
  };
}
