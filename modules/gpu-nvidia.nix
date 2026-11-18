# NVIDIA proprietary stack. Pick this OR gpu-amd per host, never both.
{ ... }:
{
  flake.modules.nixos.gpu-nvidia = { config, lib, pkgs, ... }: {
    options.my.nvidia.open = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open kernel modules. Turing (GTX 16xx / RTX 20xx) or newer only; set false for Pascal and older.";
    };

    config = {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.graphics = {
        enable = true;
        enable32Bit = true;
      };
      hardware.nvidia = {
        modesetting.enable = true;
        open = config.my.nvidia.open;
        nvidiaSettings = false;
        package = config.boot.kernelPackages.nvidiaPackages.stable;
      };
      boot.kernelParams = [ "nvidia-drm.fbdev=1" ];
      environment.sessionVariables.WLR_NO_HARDWARE_CURSORS = "1";
      environment.systemPackages = with pkgs; [ vulkan-tools ];
    };
  };
}
