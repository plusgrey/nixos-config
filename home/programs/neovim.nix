{ config, pkgs, ... }:

let
  dotfilesPath = "/home/jh/dotfiles";
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    
    # Neovim 外部依赖 (LSP, formatters, etc.)
    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server
      nil  # Nix LSP
      pyright
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted  # HTML, CSS, JSON, ESLint
      rust-analyzer
      gopls
      clang-tools  # clangd
      
      # Formatters
      stylua
      black
      isort
      prettier
      nixfmt-rfc-style
      shfmt
      
      # Linters
      eslint_d
      shellcheck
      
      # Debug adapters
      lldb
      python3Packages.debugpy  # Python debugger
      delve  # Go debugger

      
      # 其他工具
      tree-sitter
      gcc  # For treesitter compilation
    ];
  };
  
  # 链接 Neovim 配置目录
  xdg.configFile."nvim".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.config/nvim";
}
