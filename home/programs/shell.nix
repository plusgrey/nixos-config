{ config, pkgs, ... }:

let
  dotfilesPath = "/home/jh/dotfiles";
in
{
  # Zsh - 使用 Zim Framework
  programs.zsh = {
    enable = true;
    
    # 禁用 home-manager 管理的初始化，使用你的 dotfiles
    enableCompletion = false;
    
    # 环境变量
    sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
      KEYTIMEOUT = "1";
    };
    
    # Shell 别名
    shellAliases = {
      # 系统命令
      c = "clear";
      ll = "eza -la --icons";
      la = "eza -a --icons";
      ls = "eza --icons";
      lt = "eza --tree --icons";
      lh = "eza -lh --icons";
      ".." = "cd ..";
      "..." = "cd ../..";
      "~" = "cd ~";
      
      # Git
      gs = "git status";
      lg = "lazygit";
      gd = "git diff";
      ga = "git add";
      gc = "git commit";
      gp = "git push";
      gpl = "git pull";
      
      # 开发工具
      py = "python";
      px = "pixi";
      nv = "nvim";
      v = "nvim";
      
      # Tmux
      t = "tmux";
      ta = "tmux attach";
      tk = "tmux kill-session";
      tl = "tmux list-sessions";
      tn = "tmux new-session";
      
      # NixOS
      nrs = "sudo nixos-rebuild switch --flake .#nix";
      nrb = "sudo nixos-rebuild boot --flake .#nix";
      nrt = "sudo nixos-rebuild test --flake .#nix";
      ncg = "sudo nix-collect-garbage -d";
      nfu = "nix flake update";
      
      # 其他
      ff = "fastfetch";
      cat = "bat";
      grep = "rg";
      find = "fd";
    };
  };
  
  # 链接 zsh 配置文件
  home.file.".zshrc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.zshrc";
  home.file.".zimrc".source = config.lib.file.mkOutOfStoreSymlink "${dotfilesPath}/.zimrc";
  
  # Starship prompt (已禁用 - 使用 Zim 自带的 steeef 主题)
  # 如需启用，取消下面的注释
  # programs.starship = {
  #   enable = true;
  #   enableZshIntegration = true;
  #   settings = {
  #     format = ''
  #       $username$hostname$directory$git_branch$git_status$python$nodejs$rust$nix_shell$cmd_duration
  #       $character
  #     '';
  #     
  #     character = {
  #       success_symbol = "[❯](bold green)";
  #       error_symbol = "[❯](bold red)";
  #       vimcmd_symbol = "[❮](bold green)";
  #     };
  #     
  #     directory = {
  #       style = "bold cyan";
  #       truncation_length = 3;
  #       truncate_to_repo = true;
  #     };
  #     
  #     git_branch = {
  #       symbol = " ";
  #       style = "bold purple";
  #     };
  #     
  #     git_status = {
  #       style = "bold red";
  #       conflicted = "⚔️ ";
  #       ahead = "⇡\${count}";
  #       behind = "⇣\${count}";
  #       diverged = "⇕⇡\${ahead_count}⇣\${behind_count}";
  #       untracked = "?\${count}";
  #       stashed = "📦";
  #       modified = "!\${count}";
  #       staged = "+\${count}";
  #       renamed = "»\${count}";
  #       deleted = "✘\${count}";
  #     };
  #     
  #     python = {
  #       symbol = "🐍 ";
  #       style = "yellow";
  #     };
  #     
  #     nodejs = {
  #       symbol = " ";
  #       style = "green";
  #     };
  #     
  #     rust = {
  #       symbol = "🦀 ";
  #       style = "red";
  #     };
  #     
  #     nix_shell = {
  #       symbol = "❄️ ";
  #       style = "blue";
  #       format = "via [$symbol$state( \\($name\\))]($style) ";
  #     };
  #     
  #     cmd_duration = {
  #       min_time = 2000;
  #       format = "took [$duration](bold yellow) ";
  #     };
  #   };
  # };
  
  # Fzf
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultCommand = "fd --type f --hidden --follow --exclude .git";
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
    ];
    colors = {
      bg = "#1e1e2e";
      "bg+" = "#313244";
      fg = "#cdd6f4";
      "fg+" = "#cdd6f4";
      hl = "#f38ba8";
      "hl+" = "#f38ba8";
      info = "#cba6f7";
      prompt = "#cba6f7";
      pointer = "#f5e0dc";
      marker = "#f5e0dc";
      spinner = "#f5e0dc";
      header = "#f38ba8";
    };
  };
  
  # Zoxide (更智能的 cd)
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };
  
  # Atuin (更好的历史记录)
  programs.atuin = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      auto_sync = false;
      update_check = false;
      search_mode = "fuzzy";
      filter_mode = "global";
      style = "compact";
    };
  };
}
