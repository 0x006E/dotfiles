{
  delib,
  pkgs,
  config,
  ...
}:
delib.module {
  name = "services.wgcf";
  options = delib.singleEnableOption true;

  nixos.ifEnabled =
    { ... }:
    let
      fixedRoutes = [
        "100.96.0.1/32"
      ];
      routesLines = mapper: ''
        ${builtins.concatStringsSep "\n" (builtins.map mapper fixedRoutes)}
      '';

      # Improved Rule-based Routing (https://www.wireguard.com/netns/):
      # encapsulated packets carry fwmark 0x20000 and escape the tunnel via
      # the main table; everything else consults table 51820, where cfwarp-add
      # installs the default route for full-tunnel mode. The main-table
      # default is never touched, so network switches cannot strand a
      # gateway-pinned endpoint route anymore.
      warpTable = 51820;
      ensureRule = prio: args: ''
        if ! ip rule show | grep -q '^${toString prio}:'; then
          ip rule add priority ${toString prio} ${args}
        fi
      '';
      ensureRule6 = prio: args: ''
        if ! ip -6 rule show | grep -q '^${toString prio}:'; then
          ip -6 rule add priority ${toString prio} ${args}
        fi
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

      warpDispatcher = pkgs.writeShellApplication {
        name = "warp-dispatcher";
        runtimeInputs = with pkgs; [
          iproute2
          systemd
        ];
        text = builtins.readFile ./dispatcher.sh;
      };
    in
    {
      sops.secrets."cloudflare_warp_private_key" = { };

      environment.systemPackages = [
        cfwarp-add
        cfwarp-rm
      ];

      networking.networkmanager.dispatcherScripts = [
        {
          source = "${warpDispatcher}/bin/warp-dispatcher";
          type = "basic";
        }
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
          postSetup = ''
            wg set wg1 fwmark 0x20000

            ${routesLines (t: "ip route replace ${t} dev wg1 table main")}

            ${ensureRule 32764 "table main suppress_prefixlength 0"}
            ${ensureRule 32765 "not fwmark 0x20000 table ${toString warpTable}"}
            ${ensureRule6 32764 "table main suppress_prefixlength 0"}
            ${ensureRule6 32765 "not fwmark 0x20000 table ${toString warpTable}"}
          '';
          postShutdown = ''
            ip rule del priority 32764 table main suppress_prefixlength 0 2>/dev/null || true
            ip rule del priority 32765 not fwmark 0x20000 table ${toString warpTable} 2>/dev/null || true
            ip -6 rule del priority 32764 table main suppress_prefixlength 0 2>/dev/null || true
            ip -6 rule del priority 32765 not fwmark 0x20000 table ${toString warpTable} 2>/dev/null || true
            ip route flush table ${toString warpTable}
            ip -6 route flush table ${toString warpTable}
          '';
        };
        hosts."162.159.193.6" = [ "engage.cloudflareclient.com" ];
      };
    };
}
