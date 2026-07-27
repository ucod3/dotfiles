# Mac App Store applications
#
# Driven entirely by the `masApps` attrset in your `.local/settings.nix`:
#
#   masApps = { Notability = 360593530; };
#
# Find an ID: App Store → app page → right-click → Copy Link → trailing number.
# Requires an Apple ID signed into the App Store.
#
# There is no separate enable toggle. An empty `masApps` installs nothing —
# including the `mas` CLI itself, which exists only to serve this list. The
# previous shape (`apps.mas.enable` plus an mkOption default naming a specific
# app) meant a fresh fork that flipped the toggle got the upstream author's
# App Store purchases; a toggle that can disagree with the list is one more
# thing to get wrong.

{ lib, ... }:

let
  dotfilesLocal = import ../../lib/local.nix;
  cfg = dotfilesLocal.masApps;
in
{
  config = lib.mkIf (cfg != { }) {
    homebrew.brews = [
      "mas" # Mac App Store CLI (required for masApps)
    ];

    homebrew.masApps = cfg;
  };
}
