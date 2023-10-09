{
  networking.wg-quick.interfaces = {
    wg0 = {
      address = ["10.1.0.43/24"];
      privateKeyFile = "/etc/nixos/wg-privatekey";

      peers = [
        {
          publicKey = "Z92Y07+dwb8U8Kj63sMOvBWE5nNssKba7/2u1l7l5Fw=";
          allowedIPs = ["10.1.0.0/24"];
          endpoint = "vpn.purefun.fi:51820";
          persistentKeepalive = 25;
        }
      ];
    };
  };
}
