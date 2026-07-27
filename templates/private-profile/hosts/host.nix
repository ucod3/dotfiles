# Machine-specific composition for @HOSTNAME@.
{ inputs, ... }:

let
  user = "@USER@";
in
{
  imports = [
    ../apps
    ../macos
  ];

  nix-homebrew = {
    enable = true;
    enableRosetta = true;
    inherit user;
    autoMigrate = true;
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    backupFileExtension = "hm-backup";
    extraSpecialArgs = { inherit user; };

    users.${user}.imports = [
      inputs.dotfiles.darwinModules.homeEnvironment
      ../home
    ];
  };

  _module.args.user = user;
}
