{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    inputs.niri.nixosModules.niri
  ];

  # --- 1. 启动与内核 ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  # Nvidia 必选参数，防止画面撕裂和 Wayland 问题
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # --- 2. 网络与基础 ---
  networking.hostName = "nix"; 
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Singapore";
  i18n.defaultLocale = "en_US.UTF-8";

  # 额外的语言支持
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
    "zh_TW.UTF-8/UTF-8"
  ];

  # --- 3. 显卡驱动 (NVIDIA) ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = false; 
    open = false; 
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta; 
  };

  # --- 4. 桌面环境与登录器 ---
  # SDDM 登录管理器 (支持 Wayland)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    # 如果想用默认主题以外的，可以在这里配置 theme
  };
  
  # KDE Plasma 6 (作为备用/第二桌面)
  services.desktopManager.plasma6.enable = true;

  # Niri (通过 flake 启用)
  programs.niri.enable = true;

  # XWayland (用于 X11 应用兼容)
  programs.xwayland.enable = true;

  # --- 5. Noctalia Shell (Wayland 状态栏/启动器) ---
  # 注意: noctalia-shell 目前需要从 flake 或手动安装
  # 如果 flake 中有定义，可以直接使用:
  # environment.systemPackages = [ inputs.noctalia-shell.packages.${pkgs.system}.default ];
  
  # 或者使用 overlay 方式 (需要确认 noctalia-shell flake 的输出格式)

  # --- 6. 输入法 (Fcitx5) ---
  # 系统级启用，保证在任何地方都能调起守护进程
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      fcitx5-qt
      fcitx5-chinese-addons # 包含 pinyin, table 等
      fcitx5-rime           # Rime 输入法
      fcitx5-nord           # 主题，可选
    ];
    fcitx5.waylandFrontend = true;
  };

  # --- 7. 用户定义 ---
  users.users.jh = {
    isNormalUser = true;
    description = "jh";
    extraGroups = [ "networkmanager" "wheel" "video" "input" "audio" "docker" ];
    shell = pkgs.zsh;
  };

  # --- 8. 系统级开发环境 & 工具 ---
  environment.systemPackages = with pkgs; [
    # 核心工具
    git
    wget
    curl
    unzip
    gnumake
    gcc
    cmake
    
    # 搜索工具
    ripgrep
    fd
    tree
    which
    file
    
    # 语言基础环境 (用于非 Project 的随手开发)
    python3
    rustup
    nodejs
    go
    lua-language-server
    
    # 系统监控
    btop
    htop
    fastfetch
    neofetch
    
    # 网络工具
    inetutils
    dnsutils
    nmap
    
    # 文件系统
    ntfs3g
    exfat
    
    # Pixi (你的核心包管理器)
    pixi
    
    # 终端工具
    # starship   # 提示符 (已在 dotfiles 中使用 zim 自带主题)
    zellij     # 终端复用器 (tmux 替代方案)
    
    # Noctalia Shell (如果在 nixpkgs 中可用)
    # noctalia-shell
    
    # 其他实用工具
    mediainfo
    imagemagick
    ffmpeg
  ];

  # --- 9. Zsh ---
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestions.enable = true;
    syntaxHighlighting.enable = true;
  };

  # --- 10. Nix-ld (解决二进制兼容性) ---
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    stdenv.cc.cc
    zlib
    fuse3
    icu
    nss
    openssl
    curl
    expat
    libxml2
    # 常见的 Python/Node 本地构建需要的库
    libGL
    libGLU
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
  ];

  # --- 11. 游戏支持 ---
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    remotePlay.openFirewall = true;      # Steam Remote Play
    dedicatedServer.openFirewall = true; # Steam 专用服务器
  };
  programs.gamemode.enable = true;
  
  # 额外游戏工具
  environment.systemPackages = with pkgs; [
    # Steam 相关
    steam-run           # 运行非 Steam 游戏
    protontricks        # Proton 配置工具
    winetricks          # Wine 配置工具
    
    # 游戏启动器
    lutris              # 游戏启动器
    heroic              # Epic/GOG 启动器
    prismlauncher       # Minecraft 启动器
    
    # 性能监控
    mangohud            # 游戏内性能监控 OSD
    goverlay            # MangoHud 配置工具
    
    # Wine/Proton
    wine64              # Wine 64位
    winetricks          # Wine 配置
    
    # 手柄支持
    antimicrox          # 手柄映射
  ];

  # --- 12. 音频 (PipeWire) ---
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };
  
  # 禁用 PulseAudio (使用 PipeWire 替代)
  hardware.pulseaudio.enable = false;

  # --- 13. 蓝牙 ---
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
  };
  services.blueman.enable = true;

  # --- 14. 打印服务 ---
  services.printing.enable = true;

  # --- 15. 安全和权限 ---
  security.rtkit.enable = true;  # 用于 PipeWire
  security.polkit.enable = true;
  
  # sudo 无密码 (可选，开发方便)
  # security.sudo.wheelNeedsPassword = false;

  # --- 16. Docker (可选) ---
  virtualisation.docker = {
    enable = true;
    enableOnBoot = false;  # 需要时启动
  };

  # --- 17. 字体配置 ---
  fonts = {
    enableDefaultPackages = true;
    fontconfig = {
      enable = true;
      defaultFonts = {
        serif = [ "Noto Serif CJK SC" "Noto Serif" ];
        sansSerif = [ "Noto Sans CJK SC" "Noto Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" "Noto Sans Mono CJK SC" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
    packages = with pkgs; [
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      noto-fonts-emoji
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.meslo-lg
      source-han-sans
      source-han-serif
    ];
  };

  # --- 18. 环境变量 ---
  environment.sessionVariables = {
    # Wayland
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    
    # 输入法
    GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
  };

  # --- 19. Nix 设置 ---
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];
      auto-optimise-store = true;
      
      # nix-community 缓存 (加速社区包下载)
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];
    };
    
    # 定期垃圾回收 (保留最近3个版本和7天内的版本)
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 7d";
    };
  };
  
  # 保留系统版本数量 (boot menu 中显示的版本数)
  boot.loader.systemd-boot.configurationLimit = 3;
  
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "24.11"; 
}
