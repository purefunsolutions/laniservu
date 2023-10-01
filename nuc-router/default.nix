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

    nixpkgs.config.allowUnfree = true;
    hardware.enableAllFirmware = true;
    hardware.cpu.intel.updateMicrocode = true;

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
    boot.kernelModules = [
      # KVM
      "kvm-intel"
    ];

    programs = {
      mosh.enable = true;
      neovim = {
        enable = true;
        defaultEditor = true;
      };
    };
    environment.systemPackages = with pkgs; [
      # Basic "top"s
      htop
      iftop
      iotop

      wget
      curl

      ripgrep
      git

      screen
      tmux
    ];

    nix = {
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 7d";
      };
      optimise = {
        automatic = true;
        dates = ["3:00" "11:00" "15:00"];
      };
      settings = {
        trusted-users = ["root" "@wheel"];
        auto-optimise-store = true;
        experimental-features = ["nix-command" "flakes"];
      };
    };

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
      53 # DNS Server
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
    services.dnsmasq = {
      enable = true;
      settings = {
        domain-needed = true;
        bogus-priv = true;
        expand-hosts = true;
        bind-interfaces = true;
        listen-address = "10.42.0.1";
        interface = "ethlan0";
        except-interface = ["ethwan0" "wlan0"];
        dhcp-range = ["10.42.0.200,10.42.255.254,336h"];

        local = "/lan/";
        domain = "lan";

        # Static IPs
        dhcp-host = [
          "2c:f0:5d:54:49:17,10.42.0.42"
          "f8:e4:3b:09:e4:b2,10.42.0.43"
          "5c:e9:1e:86:88:2f,10.42.0.44"
        ];
      };
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
