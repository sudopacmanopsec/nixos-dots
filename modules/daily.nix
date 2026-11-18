# Daily-driver apps that don't deserve their own module. Dump stuff here.
{ ... }:
{
  flake.modules.nixos.daily = { ... }: {
    services.udisks2.enable = true;
    services.gvfs.enable = true;
  };

  flake.modules.homeManager.daily = { pkgs, ... }: {
    home.packages = with pkgs; [
      firefox
      vesktop
      mpv
      imv
      zathura
      pcmanfm
      keepassxc
      qbittorrent
    ];
  };
}
