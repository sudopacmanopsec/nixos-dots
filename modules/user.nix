{ ... }:
{
  flake.modules.nixos.user = { config, pkgs, ... }: {
    users.users.${config.my.username} = {
      isNormalUser = true;
      extraGroups = [ "wheel" "video" "audio" "input" "networkmanager" ];
      shell = pkgs.bash;
    };
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "bak";
    };
  };
}
