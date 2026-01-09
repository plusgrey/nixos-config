{ config, pkgs, ... }:

let
  dotfilesPath = "${config.home.homeDirectory}/dotfiles";
in
{
  programs.wezterm = {
    enable = true;
    # 既然已经链接了整个配置目录，这里就不需要读取文件内容了
    # 这样可以避免 builtins.readFile 带来的 impurity 问题
    # extraConfig = ... 
  };
  
  # 直接链接配置目录（这才是生效的部分）
  xdg.configFile."wezterm".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/wezterm";
}
