{
  self,
  lib,
  nixpkgs,
  nixos-generators,
  nixos-hardware,
  microvm,
}: let
  system = "x86_64-linux";
  nixosConfiguration = {
    lib,
    pkgs,
    config,
    ...
  }: {
    imports = [
      nixos-generators.nixosModules.raw-efi
    ];

    networking.hostName = "nuc-router";

    # Make it explicit we are building for x86_64
    nixpkgs.hostPlatform.system = system;

    # TODO: Add stuff from nixos-generate-config

    nixpkgs.config.allowUnfree = true;
    hardware.enableAllFirmware = true;

    boot.initrd.kernelModules = [
      # Load NVMe kernel module early in case we have been installed to NVMe
      "nvme"

      # Early KMS
      "i915"
    ];

    environment.systemPackages = [
      # Install hello world package
      pkgs.hello
    ];
  };
  out = lib.nixosSystem {
    inherit system;
    modules = [nixosConfiguration];
  };
in {
  nixosConfigurations.nuc-router = out;
  packages.x86_64-linux.nuc-router-image = out.config.system.build.${out.config.formatAttr};
}
