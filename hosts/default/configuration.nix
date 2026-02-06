{ config, pkgs, inputs, ... }:

let
  # Noctalia Shell：优先使用 nixpkgs（如果存在），否则使用 flake input。
  noctaliaShellPkg =
    if pkgs ? noctalia-shell then pkgs.noctalia-shell
    else inputs.noctalia-shell.packages.${pkgs.system}.default;

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
    backup_and_link "$homeDir/.config/ghostty" "$dotfilesDir/.config/ghostty"

    # tmux 主题/脚本常通过 run-shell 直接执行，确保有可执行权限
    if [ -d "$homeDir/.config/tmux/scripts" ]; then
      chmod -R u+rx "$homeDir/.config/tmux/scripts" 2>/dev/null || true
    fi
    chown -hR "$user:users" "$homeDir/.config" 2>/dev/null || true
  '';

  # --- 1. 启动与内核 ---
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 使用最新内核（而不是默认的 LTS 内核）
  # 原因：获取最新硬件支持和功能
  # 可选值：
  #   pkgs.linuxPackages_latest  - 最新稳定内核
  #   pkgs.linuxPackages_zen     - Zen 内核（游戏优化）
  #   pkgs.linuxPackages_xanmod  - XanMod 内核（性能优化）
  boot.kernelPackages = pkgs.linuxPackages_zen;

  # Nvidia 必选参数，防止画面撕裂和 Wayland 问题
  boot.kernelParams = [ "nvidia-drm.modeset=1" ];

  # --- 2. 网络与基础 ---
  networking.hostName = "nix";
  networking.networkmanager.enable = true;
  time.timeZone = "Asia/Singapore";
  i18n.defaultLocale = "en_US.UTF-8";

  # 只影响“界面消息”语言（不强制改变日期/数字等格式），
  # 用于避免 fcitx5 之类组件默认落到繁体翻译。
  # i18n.extraLocaleSettings = {
  #   LC_MESSAGES = "zh_CN.UTF-8";
  #   LC_CTYPE = "zh_CN.UTF-8";
  # };
  #
  # 额外的语言支持
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    # "zh_CN.UTF-8/UTF-8"
  ];
  services.openssh.enable = true;

  # --- 3. 显卡驱动 (NVIDIA) ---
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;
  hardware.graphics.enable32Bit = true; # 支持 32 位应用
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.beta;
  };

# --- 4. 桌面环境与登录器 ---
  # SDDM 登录管理器 (支持 Wayland)
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    theme = "breeze";
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
  # systemd.user.services.xwayland-satellite = {
  #   description = "XWayland Satellite for Niri";
  #   # 只在 niri 会话中启动
  #   wantedBy = [ "niri.service" ];
  #   after = [ "niri.service" ];
  #   requisite = [ "niri.service" ];
  #   serviceConfig = {
  #     Type = "simple";
  #     ExecStart = "${pkgs.xwayland-satellite}/bin/xwayland-satellite :0";
  #     Restart = "on-failure";
  #     RestartSec = 1;
  #     # 设置 DISPLAY 环境变量供子进程使用
  #     # Environment = "DISPLAY=:0";
  #     # RIME_USER_DATA_DIR = "$HOME/.local/share/fcitx5/rime";
  #   };
  # };

  # --- 6. 输入法 (Fcitx5) ---
  # 系统级启用，保证在任何地方都能调起守护进程
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      # 输入法配置等工具
      qt6Packages.fcitx5-configtool
      fcitx5-gtk
      qt6Packages.fcitx5-qt  # Qt6 支持
      qt6Packages.fcitx5-chinese-addons  # 包含 pinyin, table 等
      fcitx5-fluent
      librime
      librime-lua
      fcitx5-rime
      pkgs.rime-ice
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
    pkg-config
    gdb
    readline
    lua5_1
    lua51Packages.luarocks

    # 搜索工具
    ripgrep
    fd
    tree
    which
    file

    # 语言基础环境 (用于非 Project 的随手开发)
    python3
    rustup
    cargo
    rustc
    clang-tools
    clang
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
    direnv
    nix-direnv

    # Pixi
    pixi

    # 终端工具
    # starship   # 提示符 (已在 dotfiles 中使用 zim 自带主题)
    tmux
    zimfw  # Zim 框架管理器

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
    # gh
    zoxide
    atuin
    chafa

    # 终端/桌面应用（配置由 dotfiles 自己管）
    wezterm
    ghostty
    google-chrome
    vscode
    insomnia
    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

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

    # 文件/媒体管理器
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

  # 必须启用程序级配置来初始化 hook
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

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
    # stdenv.cc.cc
    # zlib
    # fuse3
    # icu
    # nss
    # openssl
    # curl
    # expat
    # libxml2
    # # 常见的 Python/Node 本地构建需要的库
    # libGL
    # libGLU
    # xorg.libX11
    # xorg.libXcursor
    # xorg.libXi
    # xorg.libXrandr
    # # 深度学习必备
    # linuxPackages.nvidia_x11  # 提供 libcuda.so
    # libglvnd                  # 现代 GL 供应商中立库
    # stdenv.cc.cc.lib          # 关键：提供标准 C++ 库支持
    # glib
    # binutils                  # 提供 ld 等工具
    #
    # # 常见依赖
    # libxcrypt-legacy          # 某些旧版动态链接需要
    # ncurses
    # freeglut
      # === 基础 C/C++ 运行时 ===
    stdenv.cc.cc
    stdenv.cc.cc.lib
    glibc
    libz
    libgcc

    # === 压缩和编码库 ===
    zlib
    zstd
    bzip2
    xz

    # === SSL/网络库 ===
    openssl
    curl
    libssh
    nghttp2

    # === XML/解析库 ===
    expat
    libxml2
    libxslt

    # === 图形和窗口系统 ===
    libGL
    libGLU
    libglvnd
    mesa

    # === X11 相关 ===
    xorg.libX11
    xorg.libXcursor
    xorg.libXi
    xorg.libXrandr
    xorg.libXext
    xorg.libXrender
    xorg.libxcb
    xorg.libXfixes

    # === NVIDIA/CUDA 支持 ===
    linuxPackages.nvidia_x11
    cudatoolkit
    cudaPackages.cudnn
    cudaPackages.nccl

    # === Python 二进制扩展常用库 ===
    fuse3
    icu
    nss
    ncurses
    libxcrypt-legacy
    readline
    sqlite


    # === 数学和科学计算库 ===
    openblas
    lapack
    # Intel MKL (如果需要更好的性能)
    mkl

    # === 图像处理 ===
    libjpeg
    libpng
    libtiff
    libwebp

    # === 音视频 ===
    ffmpeg
    gst_all_1.gstreamer
    gst_all_1.gst-plugins-base

    # === 其他常用库 ===
    glib
    binutils
    freeglut
    libffi
    libuuid
    attr
    libcap

    # === 添加 Python 特定的依赖 ===
    # 这些是 PyTorch 和其他科学计算包常需要的
    numactl
    libaio
    rdma-core

    # === 网络下载相关（解决 UV/pip 下载问题）===
    cacert
    openssl.dev
    krb5
    keyutils
    libev
    c-ares
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
  hardware.nvidia-container-toolkit.enable = true;

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

  #Flatpak 支持（可选）
  services.flatpak.enable = true;

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
    CUDA_PATH = "${pkgs.cudatoolkit}";

    # 某些 Python 包需要知道 OpenBLAS 的位置
    OPENBLAS = "${pkgs.openblas}";

    # SSL 证书路径
    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    CURL_CA_BUNDLE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    # 优先使用简体中文翻译（避免某些组件默认落到繁体翻译）
    LANGUAGE = "en_US";
    #LD_LIBRARY_PATH = "/run/opengl-driver/lib:/run/opengl-driver-32/lib";
      # === Rust OpenSSL 支持 ===
    OPENSSL_DIR = "${pkgs.openssl.dev}";
    OPENSSL_LIB_DIR = "${pkgs.openssl.out}/lib";
    OPENSSL_INCLUDE_DIR = "${pkgs.openssl.dev}/include";
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
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
      options = "--delete-older-than 30d";
    };
  };

  # 保留系统版本数量 (boot menu 中显示的版本数)
  boot.loader.systemd-boot.configurationLimit = 5;

  nixpkgs.config.allowUnfree = true;

  system.stateVersion = "25.11";
}
