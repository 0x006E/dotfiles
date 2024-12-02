{ pkgs, config, ... }:
let
  inherit (config.lib.formats.rasi) mkLiteral;
in
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    theme = {
      window = {
        transparency = "real";
        location = mkLiteral "center";
        anchor = mkLiteral "center";
        fullscreen = false;
        width = mkLiteral "750px";
        x-offset = mkLiteral "0px";
        y-offset = mkLiteral "0px";

        enabled = true;
        margin = mkLiteral "0px";
        padding = mkLiteral "0px";
        border = mkLiteral "0px solid";
        border-radius = mkLiteral "12px";
        border-color = mkLiteral "@selected";
        cursor = "default";
      };

      mainbox = {
        enabled = true;
        spacing = mkLiteral "0px";
        margin = mkLiteral "0px";
        padding = mkLiteral "0px";
        border = mkLiteral "0px solid";
        border-radius = mkLiteral "0px 0px 0px 0px";
        border-color = mkLiteral "@selected";
        background-color = mkLiteral "transparent";
        children = [
          "inputbar"
          "listview"
        ];
      };

      inputbar = {
        enabled = true;
        spacing = mkLiteral "10px";
        margin = mkLiteral "0px";
        padding = mkLiteral "15px";
        border = mkLiteral "0px solid";
        border-radius = mkLiteral "0px";
        border-color = mkLiteral "@selected";
        background-color = mkLiteral "@selected";
        children = [
          "prompt"
          "entry"
        ];
      };

      prompt = {
        enabled = true;
        background-color = mkLiteral "inherit";
      };

      textbox-prompt-colon = {
        enabled = true;
        expand = false;
        str = "::";
        background-color = mkLiteral "inherit";
      };

      entry = {
        enabled = true;
        background-color = mkLiteral "inherit";
        cursor = mkLiteral "text";
        placeholder = "Search...";
        placeholder-color = mkLiteral "inherit";
      };

      listview = {
        enabled = true;
        columns = 5;
        lines = 3;
        cycle = true;
        dynamic = true;
        scrollbar = false;
        layout = mkLiteral "vertical";
        reverse = false;
        fixed-height = true;
        fixed-columns = true;

        spacing = mkLiteral "5px";
        margin = mkLiteral "0px";
        padding = mkLiteral "10px";
        border = mkLiteral "0px solid";
        border-radius = mkLiteral "0px";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@foreground";
        cursor = mkLiteral "default";
      };

      scrollbar = {
        handle-width = mkLiteral "5px";
        border-radius = mkLiteral "0px";
        background-color = mkLiteral "@background-alt";
      };

      element = {
        enabled = true;
        spacing = mkLiteral "15px";
        margin = mkLiteral "0px";
        padding = mkLiteral "20px 10px";
        border = mkLiteral "0px solid";
        border-radius = mkLiteral "12px";
        border-color = mkLiteral "@selected";
        background-color = mkLiteral "transparent";
        text-color = mkLiteral "@foreground";
        orientation = mkLiteral "vertical";
        cursor = mkLiteral "pointer";
      };

      element-icon = {
        size = mkLiteral "64px";
        cursor = mkLiteral "inherit";
      };

      element-text = {
        highlight = mkLiteral "inherit";
        cursor = mkLiteral "inherit";
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.5";
      };

      error-message = {
        padding = mkLiteral "15px";
        border = mkLiteral "2px solid";
        border-radius = mkLiteral "12px";
        border-color = mkLiteral "@selected";
        background-color = mkLiteral "@background";
        text-color = mkLiteral "@foreground";
      };

      textbox = {
        background-color = mkLiteral "@background";
        vertical-align = mkLiteral "0.5";
        horizontal-align = mkLiteral "0.0";
        highlight = mkLiteral "none";
      };
    };
    extraConfig = {
      # Configuration
      modi = "drun";
      show-icons = true;
      drun-display-format = "{name}";
      display-drun = "";

    };

  };
}
