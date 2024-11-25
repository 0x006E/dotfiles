{

  programs.gpg = {
    enable = true;
    publicKeys = [
      {
        source = ./public.asc;
        trust = 5;
      }
    ];
  };
  services.gpg-agent = {
    enable = true;
    enableExtraSocket = true;
    enableSshSupport = true;
  };

}
