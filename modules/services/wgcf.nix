{ delib, inputs, ... }:
delib.module {
  name = "services.wgcf";

  nixos.always =
    { myconfig, ... }:
    {
      pkgs,
      config,
      lib,
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
        runtimeInputs = with pkgs; [ iproute2 iputils curl dnsutils ];
        text = ''
          #!/usr/bin/env bash
          set -euo pipefail
          
          # CHANGE THESE TO MATCH YOUR NETWORK
          _gateway=''${GATEWAY_IP:-192.168.1.1}
          _wan=''${WAN_INTERFACE:-eth0}
          
          _cf=$(dig +short engage.cloudflareclient.com | tail -1)
          
          echo "CF: $_cf"
          
          # make current wireguard connections permanent
          echo '>> Ensuring connection to the VPNs'
          sudo ip route replace "$_cf" via "$_gateway" dev "$_wan" || true
          
          if [ -n "''${2:-}" ]; then
            echo 'Too many arguments'
            exit 3
          fi
          
          # attempt
          echo '>> Test connection to WARP'
          sudo ip route replace 8.8.8.8 via 100.96.0.1 dev wg1
          sleep 1
          if ! ping -c 8 8.8.8.8; then
            echo '>> Failed to ping google, reverting...'
            sudo ip route del 8.8.8.8 via 100.96.0.1 dev wg1
            exit 1
          fi
          
          if [ "''${1:-}" == "-4" ]; then
            # make default through zero-trust
            echo '>> Introduce and test default IPv4 route via WARP'
            sudo ip route replace default via 100.96.0.1 dev wg1
            sleep 1
            if ! ping -c 8 1.1.1.1; then
              echo '>> Failed to ping cloudflare, reverting...'
              sudo ip route del default via 100.96.0.1 dev wg1
              sudo ip route del 8.8.8.8 via 100.96.0.1 dev wg1
              exit 2
            fi
            sudo ip -4 route flush cache
          elif [ "''${1:-}" == "-6" ]; then
            echo '>> Introduce and test default IPv6 route via WARP'
            sudo ip -6 route replace default dev wg1
            sleep 1
            curl -6 'https://google.com'
            sudo ip -6 route flush cache
          elif [ -n "''${1:-}" ]; then
            dig +short "$1" |\
              xargs -tI % \
                sudo ip route replace % via 100.96.0.1 dev wg1
          fi
          
          echo '>> Finished with success!'
        '';
      };
    in
    {
      imports = [
        inputs.sops-nix.nixosModules.sops
      ];

      sops.defaultSopsFile = ../../secrets/secrets.yaml;
      sops.defaultSopsFormat = "yaml";
      sops.age.keyFile = "/home/nithin/.config/sops/age/keys.txt";
      
      sops.secrets."cloudflare_warp/private_key" = {};

      environment.systemPackages = [ cfwarp-add ];

      networking = {
        wireguard.interfaces.wg1 = {
          # CHANGE THESE TO MATCH YOUR WGCF PROFILE
          ips = [ "2606:4700:cf1:1000::1/128" "100.96.0.1/32" ];
          privateKeyFile = config.sops.secrets."cloudflare_warp/private_key".path;
          mtu = 1280;
          peers = [
            {
              # CHANGE THIS TO MATCH YOUR WGCF PROFILE
              publicKey = "bmXOC+F1FxEMF9dyiK2H5/1SUtzH0JuVo51h2wPfgyo=";
              allowedIPs = [ "0.0.0.0/0" "::/0" ];
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
