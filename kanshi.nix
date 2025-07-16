{ pkgs, ... }:
{
  services.kanshi = {
    enable = true;
    profiles = {
      single = {
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080@60Hz";
            scale = 1.0;
            position = "0,0";
            status = "enable";
          }
        ];
      };
      dual = {
        outputs = [
          {
            criteria = "eDP-1";
            mode = "1920x1080@60Hz";
            scale = 1.0;
            position = "0,0";
            status = "enable";
          }
          {
            criteria = "HDMI-A-1";
            mode = "1920x1080@144Hz";
            scale = 1.0;
            position = "1920,0";
            status = "enable";
          }
        ];
      };
    };
  };
}
