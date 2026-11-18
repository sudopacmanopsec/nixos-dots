{ ... }:
{
  flake.modules.nixos.base = { lib, pkgs, config, ... }: {
    options.my = {
      username = lib.mkOption { type = lib.types.str; description = "primary user"; };
      dotfiles = lib.mkOption { type = lib.types.str; description = "dir holding mango/ waybar/ rofi/ foot/ mako/ (live-symlinked)"; };
      repo = lib.mkOption { type = lib.types.str; description = "where this flake lives on disk (for the rebuild alias)"; };
    };

    config = {
      boot.loader.systemd-boot.enable = lib.mkDefault true;
      boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;
      boot.loader.systemd-boot.configurationLimit = 10;
      zramSwap.enable = true;

      nix.settings = {
        experimental-features = [ "nix-command" "flakes" ];
        trusted-users = [ "root" "@wheel" ];
        auto-optimise-store = true;
      };
      nix.gc = { automatic = true; dates = "weekly"; options = "--delete-older-than 14d"; };
      nixpkgs.config.allowUnfree = true;

      networking.networkmanager.enable = true;
      hardware.enableRedistributableFirmware = true;

      time.timeZone = "Europe/London";
      i18n.defaultLocale = "en_GB.UTF-8";
      console.keyMap = "uk";

      # doas instead of sudo
      security.sudo.enable = false;
      security.doas = {
        enable = true;
        extraRules = [{ groups = [ "wheel" ]; persist = true; keepEnv = true; }];
      };

      environment.systemPackages = with pkgs; [ git curl wget pciutils usbutils unzip ];
    };
  };
}
