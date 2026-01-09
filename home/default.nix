{ config, pkgs, inputs, ... }:

let
  # ！！！注意：这是你 dotfiles 在物理磁盘上的绝对路径
  # 安装完系统后，请确保在这个路径 git clone 了你的 repo
  dotfilesPath = "/home/jh/dotfiles";
in
{
  # 导入模块化配置
  imports = [
    ./programs/tmux.nix
    ./programs/git.nix
    ./programs/shell.nix
    ./programs/tools.nix
    ./programs/neovim.nix
    ./programs/wezterm.nix
  ];

  home.username = "jh";
  home.homeDirectory = "/home/jh";

  # --- 1. 软链接配置 (OutOfStoreSymlink) ---
  # 核心逻辑：Nix 不管理文件内容，只管理"指向哪里"
  
  # Niri 窗口管理器配置
  xdg.configFile."niri/config.kdl".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/niri/config.kdl";
  
  # Noctalia Shell 配置
  xdg.configFile."noctalia".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/noctalia";
  
  # Fcitx5 (皮肤、词库、配置)
  # 假设你的 repo 里有 fcitx5 文件夹，如果没有，请注释掉这一行，避免死链
  # xdg.configFile."fcitx5".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/fcitx5";

  # Btop 配置
  xdg.configFile."btop".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/btop";

  # Fontconfig
  xdg.configFile."fontconfig".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/fontconfig";

  # --- 2. 环境变量 (Wayland & Input Method) ---
  home.sessionVariables = {
    # 告诉应用使用 Fcitx5
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";
    GLFW_IM_MODULE = "ibus";  # 某些应用需要这个
    
    # 默认编辑器
    EDITOR = "nvim";
    VISUAL = "nvim";
    
    # Wayland 相关
    MOZ_ENABLE_WAYLAND = "1";  # Firefox Wayland 支持
    QT_QPA_PLATFORM = "wayland";
    
    # XDG 规范
    XDG_CURRENT_DESKTOP = "niri";
    XDG_SESSION_TYPE = "wayland";
    
    # Pixi 路径
    PATH = "$HOME/.pixi/bin:$PATH";
  };

  # --- 3. 用户级软件 ---
  home.packages = with pkgs; [
    # 浏览器
    google-chrome
    
    # 字体 (Nix 下声明安装)
    nerd-fonts.jetbrains-mono
    nerd-fonts.meslo-lg
    nerd-fonts.fira-code
    source-han-sans       # 思源黑体 (中文)
    source-han-serif      # 思源宋体
    noto-fonts-color-emoji      # 谷歌 Noto Emoji 字体
    noto-fonts-cjk-sans   # 谷歌 Noto CJK 字体

    # Wayland 工具
    wl-clipboard          # Wayland 剪切板工具 (Neovim 依赖)
    wlr-randr             # 显示器配置
    hyprpicker            # 取色器 (Niri 下可用)
    grim                  # 截图工具
    slurp                 # 区域选择
    swappy                # 截图编辑
    mako                  # 通知守护进程
    
    # 文件管理
    nautilus              # GNOME 文件管理器
    file-roller           # 压缩文件管理
    
    # 媒体
    mpv                   # 视频播放器
    imv                   # 图片查看器
    pavucontrol           # 音频控制
    
    # 开发工具
    vscode                # VS Code
    insomnia              # API 测试工具
    
    # 系统工具
    polkit_gnome          # 权限管理
    networkmanagerapplet  # 网络管理托盘
    
    # 其他实用工具
    nwg-look              # GTK 主题设置
    qt6ct                 # Qt6 主题设置
    papirus-icon-theme    # 图标主题
  ];

  # --- 4. Direnv (项目环境隔离) ---
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # --- 5. XDG 用户目录 ---
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

  # --- 6. GTK 主题 ---
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = 24;
    };
    font = {
      name = "Noto Sans CJK SC";
      size = 11;
    };
    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = true;
    };
  };

  # --- 7. Qt 主题 ---
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
    style.name = "adwaita-dark";
  };

  # --- 8. 系统服务 ---
  services = {
    # 剪贴板管理
    cliphist.enable = true;
    
    # 通知服务 (如果 mako 没有作为系统服务运行)
    mako = {
      enable = true;
      defaultTimeout = 5000;
      borderRadius = 8;
      borderSize = 2;
      padding = "10";
      font = "JetBrainsMono Nerd Font 10";
    };
  };

  # 允许 home-manager 管理自己
  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
