# Terminal tools: cava, fastfetch and friends.
{ ... }:
{
  flake.modules.homeManager.cli = { pkgs, osConfig, ... }: {
    home.packages = with pkgs; [
      cava fastfetch btop
      eza bat fd ripgrep fzf jq tree ncdu tmux
      gh git yt-dlp ffmpeg
    ];

    programs.bash = {
      enable = true;
      shellAliases = {
        ls = "eza";
        ll = "eza -lah";
        cat = "bat -p";
        rebuild = "doas nixos-rebuild switch --flake ${osConfig.my.repo}#${osConfig.networking.hostName}";
        update = "nix flake update --flake ${osConfig.my.repo} && rebuild";
      };
    };
  };
}
