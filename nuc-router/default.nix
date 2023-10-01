{
  self,
  lib,
  nixpkgs,
  nixos-generators,
  nixos-hardware,
  microvm,
}: let
  system = "x86_64-linux";
  externalMac = "48:21:0b:56:50:4f";
  wlanMac = "74:04:f1:62:0e:c1";
  internalMac = "48:21:0b:56:3c:2a";
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

    # Networking configuration

    networking.enableIPv6 = false;

    # Set static interface names for ethernet devices used in configuration
    systemd.network.links."10-ethwan0" = {
      matchConfig.PermanentMACAddress = externalMac;
      linkConfig.Name = "ethwan0";
    };
    systemd.network.links."10-ethwlan0" = {
      matchConfig.PermanentMACAddress = wlanMac;
      linkConfig.Name = "wlan0";
    };
    systemd.network.links."10-ethlan0" = {
      matchConfig.PermanentMACAddress = internalMac;
      linkConfig.Name = "ethlan0";
    };

    networking.firewall.enable = true;
    networking.firewall.allowedTCPPorts = [
      22 # SSH
    ];
    networking.firewall.interfaces."ethlan0".allowedUDPPorts = [
      67 # DHCP Server
    ];

    # Use DHCP to get external IP address
    networking.interfaces.ethwan0.useDHCP = true;

    # Internal IP address
    networking.interfaces.ethlan0.ipv4.addresses = [
      {
        address = "10.42.0.1";
        prefixLength = 16; # subnet mask 255.255.0.0
      }
    ];
    networking.nat = {
      enable = true;
      internalInterfaces = ["ethlan0"];
      externalInterface = "ethwan0";
      forwardPorts = [
        # Example port forwards:
        # {
        #   sourcePort = 12000;
        #   destination = "10.0.0.2:22";
        #   proto = "tcp";
        # }
        # {
        #   sourcePort = 12001;
        #   destination = "10.0.0.12:12001";
        #   proto = "udp";
        # }
      ];
    };
    services.dhcpd4 = {
      enable = true;
      interfaces = ["ethlan0"]; # Only serve DHCP addresses towards LAN
      authoritative = true;
      machines = [
        {
          hostName = "bf";
          ipAddress = "10.42.0.42";
          ethernetAddress = "2c:f0:5d:54:49:17";
        }
      ];
      extraConfig = ''
        option domain-name-servers 8.8.8.8;
        option subnet-mask 255.255.255.0;

        subnet 10.42.0.0 netmask 255.255.255.0 {
          option broadcast-address 10.42.255.255;
          option routers 10.42.0.1;
          interface ethlan0;
          range 10.42.0.200 10.42.255.254;
        }
      '';
    };
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
