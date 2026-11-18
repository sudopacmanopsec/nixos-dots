{ ... }:
{
  flake.modules.nixos.editor = { ... }: {
    programs.vim = {
      enable = true;
      defaultEditor = true;
    };
  };
}
