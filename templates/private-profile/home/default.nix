# Private Home Manager configuration.
#
# Add your own Home Manager settings here. Adopted-file mappings live in the
# generated ../home.nix compatibility module, and their stored files live under
# ./files/. Keeping the generated boundary separate makes this file safe to edit.
{ ... }:

{
  imports = [
    ../home.nix
  ];
}
