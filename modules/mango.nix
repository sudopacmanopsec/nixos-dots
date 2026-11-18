{ ... }:
{
  flake.modules.nixos.mango = { pkgs, config, ... }: {
    # inputs.mango.nixosModules.mango is imported by the host file
    programs.mango.enable = true;

    # login via greetd; login shell so PATH (per-user profile) is set for the session
    services.greetd = {
      enable = true;
      settings.default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --cmd 'bash -l -c mango'";
        user = "greeter";
      };
    };

    security.polkit.enable = true;
    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = [ "wlr" "gtk" ];
    };
    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      noto-fonts
      noto-fonts-color-emoji
    ];
  };

  flake.modules.homeManager.mango = { pkgs, ... }: {
    home.packages = with pkgs; [
      waybar rofi foot mako swaybg
      cliphist wl-clipboard grim slurp wlsunset hyprpicker
      brightnessctl playerctl pavucontrol
    ];
    home.pointerCursor = {
      package = pkgs.adwaita-icon-theme;
      name = "Adwaita";
      size = 24;
      gtk.enable = true;
    };
  };
}
