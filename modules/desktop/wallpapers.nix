{ delib, pkgs, ... }:
delib.module {
  name = "desktop.wallpapers";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    systemd.services.wallfetch = {
      description = "Fetch and classify desktop wallpapers (wallhaven)";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.wallfetch}/bin/wallfetch --dir /var/lib/wallpapers";
        StateDirectory = "wallpapers";
      };
    };

    systemd.timers.wallfetch = {
      description = "Weekly wallpaper refresh";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "weekly";
        Persistent = true;
      };
    };

    # World-readable store for fetched wallpapers: the user session, the
    # day/night toggle, and the greeter (different user) all read from here.
    # Seed current-*.jpg from the active rice's stylix image so there is
    # something to show before the first fetch lands (C copies only if the
    # target is missing, so fetches are never clobbered).
    systemd.tmpfiles.rules = [
      "d /var/lib/wallpapers 0755 root root -"
      "C /var/lib/wallpapers/current-dark.jpg - - - - /etc/wallpapers/current"
      "C /var/lib/wallpapers/current-light.jpg - - - - /etc/wallpapers/current"
    ];
  };
}
