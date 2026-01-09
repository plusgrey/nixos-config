{ config, pkgs, ... }:

let
  dotfilesPath = "/home/jh/dotfiles";
in
{
  programs.wezterm = {
    enable = true;
    # 使用你的自定义配置
    extraConfig = builtins.readFile (builtins.toPath "${dotfilesPath}/.config/wezterm/wezterm.lua");
  };
  
  # 或者直接链接配置目录
  xdg.configFile."wezterm".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/wezterm";
}
