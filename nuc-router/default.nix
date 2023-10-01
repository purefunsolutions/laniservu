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
    ];

    networking.hostName = "nuc-router";

    time.timeZone = "Europe/Helsinki";
    i18n.defaultLocale = "en_US.UTF-8";
    console.keyMap = "fi";

    # Make it explicit we are building for x86_64
    nixpkgs.hostPlatform.system = system;

    # TODO: Add stuff from nixos-generate-config

    nixpkgs.config.allowUnfree = true;
    hardware.enableAllFirmware = true;

    boot.loader = {
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    boot.initrd.kernelModules = [
      # Load NVMe kernel module early in case we have been installed to NVMe
      "nvme"

      # Early KMS
      "i915"
    ];

    environment.systemPackages = with pkgs; [
      # Basic "top"s
      htop
      iftop
      iotop
    ];

    services.openssh.enable = true;
    users.users.root.openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPV/Kqv9FCXg5CIzUNDRvjCNXhcBCtWXqg8MJpaBI3xN a@b"
    ];

    system.stateVersion = "23.05";
  };
  outCfg = lib.nixosSystem {
    inherit system;
    modules = [
      nixosConfiguration

      ./hardware-configuration.nix
    ];
  };
  outImage = lib.nixosSystem {
    inherit system;
    modules = [
      nixosConfiguration

      nixos-generators.nixosModules.raw-efi
    ];
  };
in {
  nixosConfigurations.nuc-router = outCfg;
  packages.x86_64-linux.nuc-router-image = outImage.config.system.build.${outImage.config.formatAttr};
}
