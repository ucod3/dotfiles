{ config, pkgs, self, user, ... }:

{
  system.primaryUser = user;

  nixpkgs.config.allowUnfree = true;

  homebrew = {
    enable = true;

    global = {
      autoUpdate = false;
      brewfile = true;
    };

    onActivation = {
      autoUpdate = false;
      upgrade = true;
      cleanup = "uninstall";
    };

    brews = [
      "gitleaks"
      "mas"
      "sqlite"
    ];

    casks = [
      # Browsers
      "arc"
      "microsoft-edge@canary"
      "zen"

      # Development Tools
      "codex"
      "devin-desktop"
      "zed"

      # Productivity
      "amethyst"
      "ghostty"
      "insync"
      "wpsoffice"

      # Utilities
      "adobe-acrobat-reader"
      "antigravity"
      "anydesk"
      "windscribe"
    ];

    masApps = {
      Notability = 360593530;
    };
  };

  environment.systemPackages = with pkgs; [
    brave
    gh
    mkalias
    neovim
    raycast
  ];

  nix.settings = {
    experimental-features = "nix-command flakes";
    auto-optimise-store = true;
    trusted-users = ["root" "@admin"];
  };

  programs.zsh.enable = true;

  # macOS System Optimizations
  system.defaults = {
    dock.autohide = true;
    finder.FXPreferredViewStyle = "clmv";
    NSGlobalDomain = {
      ApplePressAndHoldEnabled = false;
      KeyRepeat = 2;
      InitialKeyRepeat = 15;
      AppleShowAllExtensions = true;
      NSAutomaticWindowAnimationsEnabled = false;
    };
  };

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  users.users.${user} = {
    name = user;
    home = "/Users/${user}";
  };
}
