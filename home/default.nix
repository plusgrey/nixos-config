{ config, pkgs, ... }:

{
  # 目标：dotfiles 由你手动管理（额外文件夹 + 自己的安装/链接脚本），
  # Home Manager 不再生成/链接任何应用配置文件，仅保留必要的 home 元信息。

  home.username = "jh";
  home.homeDirectory = "/home/jh";

  # XDG 用户目录（不涉及 dotfiles 内容，且通常希望自动创建）
  xdg = {
    enable = true;
    userDirs = {
      enable = true;
      createDirectories = true;
      desktop = "${config.home.homeDirectory}/Desktop";
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      music = "${config.home.homeDirectory}/Music";
      pictures = "${config.home.homeDirectory}/Pictures";
      videos = "${config.home.homeDirectory}/Videos";
    };
  };

  # 允许 home-manager 管理自己
  programs.home-manager.enable = true;

  home.stateVersion = "25.11";
}
