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

   # Ghostty terminal configuration (main terminal)
    "ghostty/config".source = ../../config/ghostty/config;
  };

  # Add you-should-use plugin to custom Oh My Zsh plugins
  home.file.".oh-my-zsh/custom/plugins/you-should-use" = {
    source = pkgs.fetchFromGitHub {
      owner = "MichaelAquilina";
      repo = "zsh-you-should-use";
      # Pin to specific commit instead of mutable branch
      rev = "f13d38f7bd98231386ad2c950b6dfbf5784d9f0d";
      sha256 = "sha256-1ojmr9+Wg5+X5Dip4sKjP4IKKACMncPQDZ8RtYQSQ80=";
    };
  };

  programs.git = {
    enable = true;

    # Use "openpgp" instead if you actively sign commits with GPG.
    signing.format = null;
  };

  programs.neovim = {
    enable = true;
    withRuby = false;
    withPython3 = false;

    # Runtime dependencies for Telescope and other plugins
    extraPackages = with pkgs; [
      ripgrep # Required for Telescope live_grep
      fd      # Required for Telescope file finder
    ];
  };

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

    # Silence dotDir deprecation: absolute path equivalent to default
    dotDir = config.home.homeDirectory;

    oh-my-zsh = {
      enable = true;
      plugins = [
        "git"
        "vscode"
        "copypath"
        "copyfile"
        # NOTE: common-aliases removed - its global `P` alias conflicts with
        # omz_urlencode's -P flag in termsupport.zsh, causing the startup error:
        # "omz_urlencode:5: command not found: pygmentize"
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
    lua-language-server
    pyright
    typescript-language-server
    shellcheck  # Static analysis for shell scripts (used by validate)
    bats      # Bash Automated Testing System for dotfiles test suite
  ];
}