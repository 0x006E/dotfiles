{
  delib,
  lib,
  ...
}:
delib.module {
  name = "services.vikunja";
  options = delib.singleEnableOption true;

  nixos.ifEnabled = { ... }: {
    services.vikunja = {
      enable = true;
      address = "127.0.0.1";
      port = 3456;
      frontendScheme = "http";
      frontendHostname = "127.0.0.1:3456";
      database.type = "sqlite";
      settings.service = {
        # Registration is closed; the admin account already exists. Flip to
        # true temporarily if a new local account is ever needed.
        enableregistration = false;
      };
    };

    # Static user instead of the module's DynamicUser: UIDs from DynamicUser
    # change across boots, which breaks ownership of the persisted sqlite db
    # below. A fixed system user keeps /var/lib/vikunja valid after reboot.
    users.users.vikunja = {
      isSystemUser = true;
      group = "vikunja";
      description = "Vikunja issue tracker";
    };
    users.groups.vikunja = { };

    systemd.services.vikunja.serviceConfig = {
      DynamicUser = lib.mkForce false;
      User = "vikunja";
      Group = "vikunja";
      # Optional env file (created by preStart); "-" keeps the service
      # starting on first boot when it doesn't exist yet.
      EnvironmentFile = [ "-/var/lib/vikunja/jwtsecret.env" ];
    };

    # Stable JWT secret outside the nix store: generated once, persisted with
    # the db, so browser sessions survive rebuilds. Agent API tokens are
    # db-backed and survive either way.
    systemd.services.vikunja.preStart = ''
      secretFile=/var/lib/vikunja/jwtsecret.env
      if [ ! -s "$secretFile" ]; then
        secret=$(tr -dc A-Za-z0-9 < /dev/urandom | head -c 64)
        printf 'VIKUNJA_SERVICE_JWTSECRET=%s\n' "$secret" > "$secretFile"
        chown vikunja:vikunja "$secretFile"
        chmod 600 "$secretFile"
      fi
    '';

    # Sqlite db + attachments + the jwtsecret above live here; without this
    # the ephemeral root wipes the tracker on every boot.
    environment.persistence."/persist".directories = [ "/var/lib/vikunja" ];
  };
}
