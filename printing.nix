{pkgs}: {
  services.avahi = {
    enable = true;
    nssmdns = true;
    openFirewall = true;
  };

  services.printing.drivers = with pkgs; [hplipWithPlugin];
}
