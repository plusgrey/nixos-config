{ config, pkgs, ... }:

{
  programs.git = {
    enable = true;
    userName = "plusgrey";
    userEmail = "plusgrey@yahoo.com";
    
    # 启用 delta (更好的 diff 显示)
    # delta = {
    #   enable = true;
    #   options = {
    #     navigate = true;
    #     light = false;
    #     side-by-side = true;
    #     line-numbers = true;
    #     syntax-theme = "Dracula";
    #   };
    # };
    
    extraConfig = {
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
      
      # 更好的 merge 体验
      merge = {
        conflictstyle = "diff3";
      };
      
      diff = {
        colorMoved = "default";
      };
      
      # URL 简写
      url = {
        "git@github.com:" = {
          insteadOf = "gh:";
        };
      };
      
      # 凭据存储
      credential.helper = "store";
      
      # 核心设置
      core = {
        editor = "nvim";
        autocrlf = "input";
        whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
      };
      
      # 颜色设置
      color = {
        ui = "auto";
      };
    };
    
    # Git 别名
    settings.aliases = {
      st = "status";
      co = "checkout";
      br = "branch";
      ci = "commit";
      lg = "log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit";
      last = "log -1 HEAD";
      unstage = "reset HEAD --";
      amend = "commit --amend --no-edit";
      undo = "reset --soft HEAD~1";
      # 常用操作
      p = "push";
      pl = "pull";
      f = "fetch";
      # 查看 diff
      d = "diff";
      ds = "diff --staged";
    };
    
    # 忽略文件
    ignores = [
      # 编辑器
      "*.swp"
      "*.swo"
      "*~"
      ".idea/"
      ".vscode/"
      "*.sublime-*"
      
      # 系统文件
      ".DS_Store"
      "Thumbs.db"
      
      # 日志和临时文件
      "*.log"
      "*.tmp"
      "*.temp"
      
      # 依赖目录
      "node_modules/"
      "__pycache__/"
      "*.pyc"
      ".env"
      ".env.local"
      
      # 构建输出
      "dist/"
      "build/"
      "*.o"
      "*.a"
      "*.so"
      
      # Nix
      "result"
      "result-*"
    ];
  };
  
  # Lazygit
  programs.lazygit = {
    enable = true;
    settings = {
      gui = {
        theme = {
          lightTheme = false;
          activeBorderColor = [ "green" "bold" ];
          inactiveBorderColor = [ "white" ];
          selectedLineBgColor = [ "reverse" ];
        };
        showFileTree = true;
        showRandomTip = false;
        showCommandLog = false;
      };
      git = {
        paging = {
          colorArg = "always";
          pager = "delta --dark --paging=never";
        };
        commit = {
          signOff = false;
        };
        merging = {
          manualCommit = false;
          args = "";
        };
      };
      os = {
        editCommand = "nvim";
        editCommandTemplate = "{{editor}} {{filename}}";
      };
      keybinding = {
        universal = {
          quit = "q";
          return = "<esc>";
          togglePanel = "<tab>";
        };
      };
    };
  };
  
  # GitHub CLI
  programs.gh = {
    enable = true;
    settings = {
      git_protocol = "ssh";
      prompt = "enabled";
    };
  };
}
