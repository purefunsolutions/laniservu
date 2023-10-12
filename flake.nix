# Laniservu
{
  description = "laniservun flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    microvm = {
      url = "github:astro/microvm.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    lancache.url = "github:boffbowsh/nix-lancache";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nixos-generators,
    nixos-hardware,
    microvm,
    lancache,
  }: let
    lib = nixpkgs.lib;
    systems = with flake-utils.lib.system; [
      x86_64-linux
    ];
  in
    # Combine list of attribute sets together
    lib.foldr lib.recursiveUpdate {} [
      (flake-utils.lib.eachSystem systems (system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in {
        formatter = pkgs.alejandra;
      }))

      # NUC router
      (import ./nuc-router {
        inherit
          self
          lib
          nixpkgs
          nixos-generators
          nixos-hardware
          microvm
          lancache
          ;
      })
    ];
}
