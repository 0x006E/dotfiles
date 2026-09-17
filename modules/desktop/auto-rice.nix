{ delib, pkgs, ... }:
delib.module {
  name = "desktop.auto-rice";
  options = delib.singleEnableOption true;

  home.ifEnabled =
    { myconfig, ... }:
    let
      username = myconfig.constants.username;
    in
    {
      home.packages = [
        pkgs.rice-toggle
        pkgs.sunwait
      ];

      # Polls the sun every 15 min; rice-toggle itself is a no-op unless the
      # polarity changed or you last toggled manually, so this never fights
      # you. Manual override lives on Mod+Shift+Y (see desktop.niri).
      systemd.user.services.rice-toggle = {
        Unit.Description = "Apply day/night desktop polarity";
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.rice-toggle}/bin/rice-toggle auto";
          Environment = "PATH=/etc/profiles/per-user/${username}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
        };
      };

      systemd.user.timers.rice-toggle = {
        Unit.Description = "Poll sun position for day/night rice";
        Timer = {
          OnCalendar = "*:0/15";
          Persistent = true;
          Unit = "rice-toggle.service";
        };
        Install.WantedBy = [ "timers.target" ];
      };
    };
}
