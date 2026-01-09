{ config, pkgs, ... }:

let
  dotfilesPath = "${config.home.homeDirectory}/dotfiles";
in
{
  # Yazi 文件管理器
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      manager = {
        ratio = [ 1 4 3 ];
        sort_by = "alphabetical";
        sort_sensitive = false;
        sort_reverse = false;
        sort_dir_first = true;
        linemode = "none";
        show_hidden = false;
        show_symlink = true;
        scrolloff = 5;
      };
      preview = {
        tab_size = 2;
        max_width = 600;
        max_height = 900;
        image_filter = "triangle";
        image_quality = 75;
      };
    };
  };
  
  # 链接 yazi 配置
  xdg.configFile."yazi/keymap.toml".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/yazi/keymap.toml";
  xdg.configFile."yazi/theme-dark.toml".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/yazi/theme-dark.toml";
  xdg.configFile."yazi/theme-light.toml".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/yazi/theme-light.toml";
  
  # Btop 系统监控
  programs.btop = {
    enable = true;
    settings = {
      color_theme = "Default";
      theme_background = false;
      truecolor = true;
      vim_keys = true;
      rounded_corners = true;
      graph_symbol = "braille";
      update_ms = 2000;
      proc_sorting = "memory";
      proc_tree = false;
      proc_colors = true;
      proc_gradient = true;
    };
  };
  
  # Bat (更好的 cat)
  programs.bat = {
    enable = true;
    config = {
      theme = "Dracula";
      italic-text = "always";
      paging = "auto";
      style = "numbers,changes,header";
    };
  };
  
  # Eza (更好的 ls)
  programs.eza = {
    enable = true;
    enableZshIntegration = true;
    git = true;
    icons = "auto";
    extraOptions = [
      "--group-directories-first"
      "--header"
    ];
  };
  
  # Ripgrep
  programs.ripgrep = {
    enable = true;
    arguments = [
      "--smart-case"
      "--hidden"
      "--glob=!.git/*"
    ];
  };
  
  # fd (更好的 find)
  home.packages = with pkgs; [
    fd
    jq          # JSON 处理
    yq          # YAML 处理
    tree        # 目录树
    ncdu        # 磁盘使用分析
    tldr        # 简化的 man pages
    trash-cli   # 安全删除
    unzip
    zip
    p7zip
    aria2       # 下载工具
  ];
}
