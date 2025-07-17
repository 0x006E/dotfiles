{ pkgs, ... }:
{
  services.kanshi = {
    enable = true;
    settings = [
      {
        profile = {
          name = "single";

          outputs = [
            {
              criteria = "eDP-1";
              status = "enable";
            }
          ];
        };
      }
      {
        profile = {
          name = "dual";

          outputs = [
            {
              criteria = "eDP-1";
              position = "0,0";
              status = "enable";
            }
            {
              criteria = "HDMI-A-1";
              adaptiveSync = true;
              mode = "1920x1080@144Hz";
              position = "1920,0";
              status = "enable";
            }
          ];
        };
      }
    ];
  };
}
