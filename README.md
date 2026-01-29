# NixOS 安装与配置指南

本指南将帮助你从零开始安装 NixOS 并应用这套配置。

## 📋 目录结构

```
nix-config/
├── flake.nix                    # Flake 入口配置
├── home/
│   ├── default.nix              # Home Manager 主配置
│   └── programs/
│       ├── git.nix              # Git & Lazygit 配置
│       ├── neovim.nix           # Neovim 配置
│       ├── shell.nix            # Zsh & Starship 配置
│       ├── tmux.nix             # Tmux 配置
│       ├── tools.nix            # Yazi, Btop, Bat 等工具
│       └── wezterm.nix          # Wezterm 配置
└── hosts/
    └── default/
        ├── configuration.nix    # 系统配置
        └── hardware-configuration.nix  # 硬件配置 (自动生成)
```

## ✅ 管理策略（重要）

这套配置现在遵循：

- **dotfiles：你手动管理**（例如 `~/dotfiles` + 自己的 `install.sh`/软链接脚本）
- **NixOS：只负责系统级依赖**（软件包、服务、驱动、输入法、字体等）
- **Home Manager：不再生成/链接任何应用配置文件**（避免覆盖你的 dotfiles）

另外：

- **Noctalia Shell** 通过 flake input 提供（而不是强依赖 nixpkgs 里一定存在同名包）
- 你的 dotfiles 会调用 `qs -c noctalia-shell ...`，因此系统需要提供 **QuickShell（`qs`）**

## 🚀 安装步骤

### 第一阶段：安装 NixOS 基础系统

#### 1. 准备安装介质

1. 从 [NixOS 官网](https://nixos.org/download.html) 下载 ISO
2. 使用 Ventoy、Rufus 或 `dd` 命令制作启动盘

```bash
# Linux/macOS 使用 dd
sudo dd if=nixos-*.iso of=/dev/sdX bs=4M status=progress
```

#### 2. 启动并进入安装环境

1. 从 U 盘启动，选择 NixOS Installer
2. 进入 Live 环境后，连接网络：

```bash
# 有线网络自动连接
# WiFi 连接
sudo systemctl start wpa_supplicant
wpa_cli
> add_network
> set_network 0 ssid "你的WiFi名称"
> set_network 0 psk "你的WiFi密码"
> enable_network 0
> quit
```

#### 3. 磁盘分区

```bash
# 查看磁盘
lsblk

# 使用 parted 或 gdisk 分区 (以 /dev/nvme0n1 为例)
sudo parted /dev/nvme0n1 -- mklabel gpt

# EFI 分区 (512MB)
sudo parted /dev/nvme0n1 -- mkpart ESP fat32 1MiB 512MiB
sudo parted /dev/nvme0n1 -- set 1 esp on

# Root 分区 (剩余空间)
sudo parted /dev/nvme0n1 -- mkpart primary 512MiB 100%

# 格式化
sudo mkfs.fat -F 32 -n boot /dev/nvme0n1p1
sudo mkfs.ext4 -L nixos /dev/nvme0n1p2

# 挂载
sudo mount /dev/disk/by-label/nixos /mnt
sudo mkdir -p /mnt/boot
sudo mount /dev/disk/by-label/boot /mnt/boot
```

#### 4. 生成初始配置

```bash
sudo nixos-generate-config --root /mnt
```

这会在 `/mnt/etc/nixos/` 生成 `configuration.nix` 和 `hardware-configuration.nix`

#### 5. 临时修改配置以启用 Flakes

编辑 `/mnt/etc/nixos/configuration.nix`，添加：

```nix
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # 临时安装必需工具
  environment.systemPackages = with pkgs; [
    git
    vim
  ];
  
  # 设置用户
  users.users.plusgrey = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" ];
  };
  
  # 启用网络
  networking.networkmanager.enable = true;
}
```

#### 6. 安装基础系统

```bash
sudo nixos-install

# 设置 root 密码
# 设置完成后重启
reboot
```

---

### 第二阶段：应用 Flake 配置

#### 1. 登录并准备环境

```bash
# 以 plusgrey 用户登录
# 设置用户密码（如果还没设置）
passwd

# 确保网络连接
nmcli device wifi connect "你的WiFi" password "密码"
```

#### 2. 克隆配置仓库

```bash
# 创建目录
mkdir -p ~/Projects
cd ~/Projects

# 克隆 nix-config
git clone git@github.com:plusgrey/nixos-config.git

# 克隆 dotfiles
mkdir -p ~/dotfiles
git clone https://github.com/plusgrey/dotfiles.git ~/dotfiles
```

应用 Nix 配置后，再执行你的 dotfiles 安装/链接流程（例如）：

```bash
cd ~/dotfiles
./install.sh
```

#### 3. 复制硬件配置

```bash
# 复制自动生成的硬件配置到你的 flake
cp /etc/nixos/hardware-configuration.nix ~/Projects/nix-config/hosts/default/
```

#### 4. 修改配置

根据你的实际情况修改以下文件：

**flake.nix:**
- 确认用户名和主机名

**hosts/default/configuration.nix:**
- 修改 `networking.hostName` 为你想要的主机名
- 检查 NVIDIA 驱动设置（如果使用其他显卡，删除或修改相关配置）

**home/default.nix:**
- 不再需要配置 `dotfilesPath`；Home Manager 不会再替你链接/管理 dotfiles

#### 5. 首次构建

```bash
cd ~/Projects/nix-config

# 构建并切换
sudo nixos-rebuild switch --flake .#mysystem
```

> **注意**: 首次构建会下载大量包，可能需要较长时间

#### 6. 安装后配置

```bash
# 安装 Zim (Zsh 框架)
curl -fsSL https://raw.githubusercontent.com/zimfw/install/master/install.zsh | zsh

# 安装 Pixi (Python 包管理器)
curl -fsSL https://pixi.sh/install.sh | sh

# 重新登录以应用所有更改
exit
```

---

## 🔧 日常使用

### 更新系统

```bash
cd ~/Projects/nix-config

# 更新 flake inputs
nix flake update

# 应用更新
sudo nixos-rebuild switch --flake .#mysystem
```

### 快捷命令 (已在 shell.nix 中配置)

```bash
nrs    # sudo nixos-rebuild switch --flake .#nix
nrb    # sudo nixos-rebuild boot --flake .#nix
nrt    # sudo nixos-rebuild test --flake .#nix
ncg    # sudo nix-collect-garbage -d
nfu    # nix flake update
```

### 回滚到上一个版本

```bash
# 列出所有版本
sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# 回滚
sudo nixos-rebuild switch --rollback
```

---

## 📝 注意事项

### dotfiles 路径

确保你的 dotfiles 结构如下：

```
~/dotfiles/
├── .zshrc
├── .zimrc
├── .tmux.conf
├── .gitconfig
└── .config/
    ├── btop/
    ├── fontconfig/
    ├── niri/
    ├── noctalia/
    ├── nvim/
    ├── tmux/
    ├── wezterm/
    └── yazi/
```

### Noctalia Shell

Noctalia Shell 目前可能需要手动安装或从 AUR/Flake 获取：

```bash
# 如果使用 Flake
# 在 flake.nix 中已经添加了 noctalia-shell input
# 需要确认其输出格式并相应调整 configuration.nix
```

### 常见问题

1. **构建失败**: 检查 `hardware-configuration.nix` 是否正确复制
2. **显示问题**: 确认 NVIDIA 驱动设置，或在非 NVIDIA 显卡上删除相关配置
3. **网络问题**: 确保 NetworkManager 已启用
4. **输入法不工作**: 确保 Fcitx5 环境变量已设置，重新登录

---

## 📚 参考资源

- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Home Manager Manual](https://nix-community.github.io/home-manager/)
- [Nix Pills](https://nixos.org/guides/nix-pills/)
- [NixOS Wiki](https://wiki.nixos.org/)
- [Niri Window Manager](https://github.com/YaLTeR/niri)

---

## 🎯 配置包含的软件

### 系统级
- Niri (Wayland 窗口管理器)
- KDE Plasma 6 (备用桌面)
- Fcitx5 + Rime (输入法)
- PipeWire (音频)
- Docker
- **Steam + Gamemode + Gamescope** (游戏平台)
- **Lutris + Heroic** (第三方游戏启动器)
- **MangoHud** (游戏内性能监控)
- **Wine/Proton** (Windows 游戏兼容层)
- **Prismlauncher** (Minecraft 启动器)

### 用户级
- **终端**: Wezterm, Tmux
- **编辑器**: Neovim (with LSP)
- **Shell**: Zsh + Zim + Starship
- **Git**: Git + Delta + Lazygit + GitHub CLI
- **文件管理**: Yazi, Nautilus
- **工具**: Btop, Bat, Eza, Fzf, Ripgrep, Fd, Zoxide
- **浏览器**: Zen, Chrome
