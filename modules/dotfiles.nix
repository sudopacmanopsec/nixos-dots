# Live-editable dotfiles: ~/.config/<app> -> symlink into my.dotfiles (no rebuild needed to tweak).
{ ... }:
{
  flake.modules.homeManager.dotfiles = { config, osConfig, pkgs, ... }:
    let
      d = osConfig.my.dotfiles;
      link = config.lib.file.mkOutOfStoreSymlink;
      wrap = name: file: pkgs.writeShellScriptBin name ''exec ${pkgs.bash}/bin/bash ${d}/mango/scripts/${file} "$@"'';
    in {
      xdg.configFile = {
        "mango".source = link "${d}/mango";
        "waybar".source = link "${d}/waybar";
        "rofi".source = link "${d}/rofi";
        "foot".source = link "${d}/foot";
        "mako".source = link "${d}/mako";
      };
      # absolute-path wrappers so mango binds don't depend on ~ / $HOME expansion
      home.packages = [
        (wrap "mango-screenshot" "screenshot.sh")
        (wrap "mango-wallpaper" "wallpaper.sh")
      ];
    };
}
