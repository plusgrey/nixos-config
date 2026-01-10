{ config, pkgs, inputs, ... }:

let
  # Noctalia Shell：优先使用 nixpkgs（如果存在），否则使用 flake input。
  noctaliaShellPkg =
    if pkgs ? noctalia-shell then pkgs.noctalia-shell
    else inputs.noctalia-shell.packages.${pkgs.system}.default;

  # Rime 方案数据（雾凇拼音 / rime-ice 等）。
  # 某些渠道/版本的 nixpkgs 里可能没有这些属性，所以这里做了兼容。
  # rimeDataPkg = if builtins.hasAttr "rime-data" pkgs then pkgs."rime-data" else null;
  # rimeIcePkg = if builtins.hasAttr "rime-ice" pkgs then pkgs."rime-ice" else null;
  # rimeSchemaPkgs = builtins.filter (p: p != null) [ rimeDataPkg rimeIcePkg ];

  # 让 Chrome 在 Wayland 下也能正常使用输入法（KDE Wayland 常见问题）。
  # 说明：用 symlinkJoin + wrapProgram 保留 .desktop 文件（否则 App Launcher 扫不到 Chrome）。
  googleChromeIme = pkgs.symlinkJoin {
    name = "google-chrome-ime";
    paths = [ pkgs.google-chrome ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      for bin in "$out/bin/google-chrome-stable" "$out/bin/google-chrome"; do
        if [ -x "$bin" ]; then
          wrapProgram "$bin" --add-flags "--enable-wayland-ime --ozone-platform-hint=auto"
        fi
      done
    '';
  };

in
{
  imports = [
    ./hardware-configuration.nix
    inputs.niri.nixosModules.niri
  ];

  # --- Dotfiles: 不使用 Home Manager，直接在激活阶段创建软链接 ---
  # 约定：你的 dotfiles 在 /home/jh/dotfiles
  # 说明：如果目标路径已存在且不是软链接，会先移动成 .bak（重复时追加时间戳）。
  system.activationScripts.dotfilesSymlinks.text = ''
    set -euo pipefail

    user="jh"
    homeDir="/home/$user"
    dotfilesDir="$homeDir/dotfiles"

    if [ ! -d "$dotfilesDir" ]; then
      echo "[dotfiles] skip: $dotfilesDir not found"
      exit 0
    fi

    backup_and_link() {
      local target="$1"
      local source="$2"

      if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup="$target.bak"
        if [ -e "$backup" ] || [ -L "$backup" ]; then
          backup="$target.bak.$(date +%s)"
        fi
        echo "[dotfiles] backup: $target -> $backup"
        mv "$target" "$backup"
      fi

      mkdir -p "$(dirname "$target")"
      ln -sfn "$source" "$target"
    }

    # shell
    backup_and_link "$homeDir/.zshrc"  "$dotfilesDir/.zshrc"
    backup_and_link "$homeDir/.zimrc"  "$dotfilesDir/.zimrc"

    # tmux
    if [ -e "$dotfilesDir/.tmux.conf" ]; then
      backup_and_link "$homeDir/.tmux.conf" "$dotfilesDir/.tmux.conf"
    fi

    # git (如果你用 dotfiles 管理 ~/.gitconfig)
    if [ -e "$dotfilesDir/.gitconfig" ]; then
      backup_and_link "$homeDir/.gitconfig" "$dotfilesDir/.gitconfig"
    fi

    # configs under ~/.config
    backup_and_link "$homeDir/.config/nvim"    "$dotfilesDir/.config/nvim"
    backup_and_link "$homeDir/.config/tmux"    "$dotfilesDir/.config/tmux"
    backup_and_link "$homeDir/.config/yazi"    "$dotfilesDir/.config/yazi"
    backup_and_link "$homeDir/.config/wezterm" "$dotfilesDir/.config/wezterm"
    backup_and_link "$homeDir/.config/niri"     "$dotfilesDir/.config/niri"
    backup_and_link "$homeDir/.config/noctalia" "$dotfilesDir/.config/noctalia"

    # fcitx5/rime 用户词库与方案（建议用 dotfiles 管理，比如放入 rime-ice）
    # 期望结构：~/dotfiles/.local/share/fcitx5/rime
    if [ -d "$dotfilesDir/.local/share/fcitx5/rime" ]; then
      backup_and_link "$homeDir/.local/share/fcitx5/rime" "$dotfilesDir/.local/share/fcitx5/rime"
    fi

    # tmux 主题/脚本常通过 run-shell 直接执行，确保有可执行权限
    if [ -d "$homeDir/.config/tmux/scripts" ]; then
      chmod -R u+rx "$homeDir/.config/tmux/scripts" 2>/dev/null || true
    fi
    chown -hR "$user:users" "$homeDir/.config" 2>/dev/null || true
  '';

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

  # 只影响“界面消息”语言（不强制改变日期/数字等格式），
  # 用于避免 fcitx5 之类组件默认落到繁体翻译。
  i18n.extraLocaleSettings = {
    LC_MESSAGES = "zh_CN.UTF-8";
    LC_CTYPE = "zh_CN.UTF-8";
  };

  # 额外的语言支持
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "zh_CN.UTF-8/UTF-8"
  ];

  # --- 3. 显卡驱动 (NVIDIA) ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true; # 支持 32 位应用
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
  programs.niri = {
    enable = true;
    # 临时修复构建失败：禁用测试
    package = pkgs.niri.overrideAttrs (old: { doCheck = false; });
  };

  # XWayland (用于 X11 应用兼容)
  programs.xwayland.enable = true;

  # --- 5.1 xwayland-satellite 用户服务 ---
  # 原因：Niri 是纯 Wayland 合成器，不内置 XWayland 支持
  # xwayland-satellite 提供独立的 XWayland 实现，让 Steam 等 X11 应用能运行
  # 预期效果：登录 Niri 后自动启动 xwayland-satellite，Steam 可以正常打开
  # 注意：只在 Niri 会话中启动，不影响 KDE Plasma
  systemd.user.services.xwayland-satellite = {
    description = "XWayland Satellite for Niri";
    # 只在 niri 会话中启动
    wantedBy = [ "niri.service" ];
    after = [ "niri.service" ];
    requisite = [ "niri.service" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite :0";
      Restart = "on-failure";
      RestartSec = 1;
      # 设置 DISPLAY 环境变量供子进程使用
      Environment = "DISPLAY=:0";
    };
  };

  # --- 6. 输入法 (Fcitx5) ---
  # 系统级启用，保证在任何地方都能调起守护进程
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      qt6Packages.fcitx5-qt  # Qt6 支持
      qt6Packages.fcitx5-chinese-addons  # 包含 pinyin, table 等
      kdePackages.fcitx5-qt
      fcitx5-nord
      librime
      librime-lua
      rime-ice #雾凇拼音方案
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
    fastfetch
    
    # 网络工具
    inetutils
    dnsutils
    nmap
    
    # 文件系统
    ntfs3g
    exfat
    
    # Pixi 
    pixi
    
    # 终端工具
    # starship   # 提示符 (已在 dotfiles 中使用 zim 自带主题)
    tmux

    # dotfiles 相关依赖（仅提供命令/运行时，不管理配置文件内容）
    fzf
    jq
    wl-clipboard
    xclip
    xsel

    # 常用 CLI（你的 dotfiles / 工作流会用到）
    neovim
    yazi
    bat
    eza
    lazygit
    gh
    zoxide
    atuin

    # 终端/桌面应用（配置由 dotfiles 自己管）
    wezterm
    googleChromeIme
    vscode
    insomnia

    # Wayland & 桌面常用工具
    wlr-randr
    hyprpicker
    grim
    slurp
    swappy

    # Noctalia dotfiles 依赖：提供 `qs` 命令（niri/config.kdl 与 noctalia/settings.json 会调用）
    quickshell

    # Noctalia 文档里的必需依赖
    gpu-screen-recorder
    brightnessctl

    # Noctalia 常用可选依赖（不强制，但很多模块会用到）
    cliphist
    matugen
    cava
    wlsunset
    evolution-data-server

    # 输入法配置等工具
    qt6Packages.fcitx5-configtool

    # 文件/媒体
    nautilus
    file-roller
    mpv
    imv
    pavucontrol

    # 系统托盘/主题工具
    polkit_gnome
    networkmanagerapplet
    nwg-look
    qt6Packages.qt6ct
    papirus-icon-theme
    
    # Noctalia Shell（二选一来源：nixpkgs 或 flake input）
    noctaliaShellPkg
    
    # 其他实用工具
    mediainfo
    imagemagick
    ffmpeg
    
    # --- 游戏工具 ---
    # Steam 相关
    steam-run           # 运行非 Steam 游戏
    protontricks        # Proton 配置工具
    xwayland-satellite # 让 Proton 在 Wayland 下更稳定运行的辅助工具 
    # 游戏启动器
    # lutris              # 游戏启动器
    # heroic              # Epic/GOG 启动器
    prismlauncher       # Minecraft 启动器
    
    # 性能监控
    mangohud            # 游戏内性能监控 OSD
    goverlay            # MangoHud 配置工具
    
    # Wine/Proton
    wine64              # Wine 64位
    winetricks          # Wine 配置工具
    
    # 手柄支持
    antimicrox          # 手柄映射
  ];

  # --- 9. Zsh ---
  programs.zsh = {
    enable = true;
    # completion / autosuggestions / highlighting 交给 Zim 管理，避免重复初始化导致警告。
    enableCompletion = false;
    autosuggestions.enable = false;
    syntaxHighlighting.enable = false;
  };

  # 某些程序/配置会硬编码 /bin/zsh（NixOS 默认没有 /bin）。
  # 用 tmpfiles 更可靠：开机就会确保软链接存在。
  systemd.tmpfiles.rules = [
    "d /bin 0755 root root - -"
    "L+ /bin/zsh - - - - ${pkgs.zsh}/bin/zsh"
    "L+ /bin/bash - - - - ${pkgs.bashInteractive}/bin/bash"
    "L+ /bin/sh - - - - ${pkgs.bashInteractive}/bin/sh"
  ];

  environment.sessionVariables.SHELL = "${pkgs.zsh}/bin/zsh";

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
  services.pulseaudio.enable = false;

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
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.meslo-lg
      source-han-sans
      source-han-serif
    ];
  };

  # --- 图标主题（Papirus）---
  # GTK 会从 xdg settings.ini 读取默认 icon theme。
  environment.etc."xdg/gtk-3.0/settings.ini".text = ''
    [Settings]
    gtk-icon-theme-name=Papirus-Dark
  '';
  environment.etc."xdg/gtk-4.0/settings.ini".text = ''
    [Settings]
    gtk-icon-theme-name=Papirus-Dark
  '';

  # Qt 图标主题：qt6ct/qt5ct 会读取这些默认配置。
  # 注意：如果你在 ~/.config/qt6ct/qt6ct.conf 或 ~/.config/qt5ct/qt5ct.conf 里有本地配置，会覆盖这里。
  environment.etc."xdg/qt6ct/qt6ct.conf".text = ''
    [Appearance]
    icon_theme=Papirus-Dark
  '';
  environment.etc."xdg/qt5ct/qt5ct.conf".text = ''
    [Appearance]
    icon_theme=Papirus-Dark
  '';

  # --- 18. 环境变量 ---
  environment.sessionVariables = {
    # Wayland
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";
    
    # 输入法
    #GTK_IM_MODULE = "fcitx";
    QT_IM_MODULE = "fcitx";
    XMODIFIERS = "@im=fcitx";
    SDL_IM_MODULE = "fcitx";

    # 注意：DISPLAY 环境变量不在这里设置
    # 对于 Niri，在 niri config.kdl 的 environment 块中设置 DISPLAY=":0"
    # 对于 KDE Plasma，不需要手动设置 DISPLAY

    # 优先使用简体中文翻译（避免某些组件默认落到繁体翻译）
    LANGUAGE = "zh_CN:en_US";
  };

  # Wayland Portal（让 Wayland 应用与桌面集成更稳定；Noctalia 部分功能也会用到）
  xdg.portal = {
    enable = true;
    wlr.enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
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
  boot.loader.systemd-boot.configurationLimit = 5;
  
  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11"; 
}
