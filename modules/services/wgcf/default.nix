{ delib, ... }:
delib.module {
  name = "services.wgcf";

  nixos.always =
    { ... }:
    {
      pkgs,
      config,
      ...
    }:
    let
      fixedRoutes = [
        "100.96.0.1/32"
      ];
      routesLines = mapper: ''
        ${builtins.concatStringsSep "\n" (builtins.map mapper fixedRoutes)}
      '';

      cfwarp-add = pkgs.writeShellApplication {
        name = "cfwarp-add";
        runtimeInputs = with pkgs; [
          iproute2
          iputils
          curl
          dnsutils
          systemd
        ];
        text = builtins.readFile ./add.sh;
      };

      cfwarp-rm = pkgs.writeShellApplication {
        name = "cfwarp-rm";
        runtimeInputs = with pkgs; [
          iproute2
          dnsutils
          systemd
        ];
        text = builtins.readFile ./rm.sh;
      };
    in
    {
      sops.secrets."cloudflare_warp_private_key" = { };

      environment.systemPackages = [
        cfwarp-add
        cfwarp-rm
      ];

      networking = {
        wireguard.interfaces.wg1 = {
          # CHANGE THESE TO MATCH YOUR WGCF PROFILE
          ips = [
            "2606:4700:cf1:1000::1/128"
            "100.96.0.1/32"
          ];
          privateKeyFile = config.sops.secrets."cloudflare_warp_private_key".path;
          mtu = 1280;
          peers = [
            {
              # CHANGE THIS TO MATCH YOUR WGCF PROFILE
              publicKey = "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=";
              allowedIPs = [
                "0.0.0.0/0"
                "::/0"
              ];
              endpoint = "162.159.193.6:2408";
              persistentKeepalive = 15;
              name = "engage";
            }
          ];
          # I have access to all the network through allowedIPs
          # But I prefer to specify which routes to access
          allowedIPsAsRoutes = false;
          postSetup = routesLines (t: "ip route replace ${t} dev wg1 table main");
          postShutdown = routesLines (t: "ip route del ${t} dev wg1");
        };
        hosts."162.159.193.6" = [ "engage.cloudflareclient.com" ];
      };
    };
}
