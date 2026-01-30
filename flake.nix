{
  description = "NixOS Configuration for Plusgrey";

  inputs = {
    # 使用 Unstable 分支，适合开发和游戏
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # 稳定分支，用于某些需要稳定版本的软件
    nixpkgs-stable.url = "github:nixos/nixpkgs/nixos-25.11";

    # Niri Flake: 获取最新版 Niri 合成器
    niri.url = "github:sodiboo/niri-flake";

    # Noctalia Shell (Wayland 状态栏)
    noctalia-shell = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-stable, niri, ... }@inputs:
  let
    system = "x86_64-linux";

    # 导入稳定版 pkgs
    pkgs-stable = import nixpkgs-stable {
      inherit system;
      config.allowUnfree = true;
    };
  in
  {
    nixosConfigurations = {
      # 主机名定义为 nix (与 configuration.nix 中 networking.hostName 匹配)
      nix = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit inputs pkgs-stable;
        };
        modules = [
          ./hosts/default/configuration.nix
        ];
      };
    };
  };
}
