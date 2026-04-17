{ config, pkgs, self, ... }:

{
  system.primaryUser = "usmanbutt";

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
      "adobe-acrobat-reader"
      "antigravity"
      "anydesk"
      "amethyst"
      "arc"
      "codex"
      "microsoft-edge@canary"
      "ghostty"
      "insync"
      "windscribe"
      "wpsoffice"
      "windsurf"
      "zed"
      "zen"
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

  nix.settings.experimental-features = "nix-command flakes";

  programs.zsh.enable = true;

  system.configurationRevision = self.rev or self.dirtyRev or null;
  system.stateVersion = 6;

  users.users.usmanbutt = {
    name = "usmanbutt";
    home = "/Users/usmanbutt";
  };
}
