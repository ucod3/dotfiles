{ config, pkgs, ... }:

{
  home.stateVersion = "24.05";
  xdg.enable = true;

  xdg.configFile = {
    "git/config".source = ../../config/git/config;
    "git/.gitignore".source = ../../config/git/.gitignore;

    "nvim" = {
      source = ../../config/nvim;
      recursive = true;
    };

    "windsurf/config.json".source = ../../config/windsurf/config.json;
    "Code - Insiders/User/settings.json".source = ../../config/vscode/settings.json;

    # Add these later after you copy the real files into the repo.
    # "zed/settings.json".source = ../../config/zed/settings.json;
    # "neofetch/config.conf".source = ../../config/neofetch/config.conf;
    # "ghostty/config".source = ../../config/ghostty/config;
  };

  # Add you-should-use plugin to custom Oh My Zsh plugins
  home.file.".oh-my-zsh/custom/plugins/you-should-use" = {
    source = pkgs.fetchFromGitHub {
      owner = "MichaelAquilina";
      repo = "zsh-you-should-use";
      rev = "master";
      sha256 = "sha256-1ojmr9+Wg5+X5Dip4sKjP4IKKACMncPQDZ8RtYQSQ80=";
    };
  };

  programs.git = {
    enable = true;

    # Use "openpgp" instead if you actively sign commits with GPG.
    signing.format = null;
  };

  programs.neovim.enable = true;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd" "cd" ];
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    # Silence the dotDir warning and keep current behavior.
    dotDir = config.home.homeDirectory;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "vscode"
        "copypath"
        "copyfile"
        "common-aliases"
        "you-should-use"
      ];
      theme = "robbyrussell";
      custom = "$HOME/.oh-my-zsh/custom";
    };

    history = {
      path = "${config.xdg.cacheHome}/zsh/history";
      size = 100000;
      save = 20000;
      ignoreDups = true;
      expireDuplicatesFirst = true;
      ignoreSpace = true;
      share = false;
    };

    envExtra = builtins.readFile ../../config/zsh/.zshenv;
    profileExtra = builtins.readFile ../../config/zsh/.zprofile;
    initContent = builtins.readFile ../../config/zsh/custom.zsh;
  };

  home.packages = with pkgs; [
    pnpm
    python312Packages.pygments
  ];
}