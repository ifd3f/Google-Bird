{ pkgs, lib, config, ... }:
let
  cfg = config.services.googlebird;
  defaultUser = "googlebird";
in with lib; {
  options.services.googlebird = {
    enable = mkEnableOption "googlebird";
    user = mkOption {
      type = types.str;
      description = "User to run under";
      default = defaultUser;
    };
    group = mkOption {
      type = types.str;
      description = "Group to run under";
      default = defaultUser;
    };
    server = mkOption {
      type = types.str;
      description = "Fediverse server to post to";
      example = "https://fedi.astrid.tech";
    };
    postOnCalendar = mkOption {
      type = types.str;
      description = "systemd OnCalendar specification";
      default = "*-*-* *:30:00";
    };
    accessTokenFile = mkOption {
      type = types.path;
      description = ''
        Path to file containing the access token.

        To generate one, see here: https://prplecake.github.io/pleroma-access-token/
      '';
      default = "/var/lib/secrets/googlebird/accessToken";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.googlebird-config = {
      description = "Set up googlebird required directories";
      environment = { inherit (cfg) user group accessTokenFile; };

      script = ''
        mkdir -p "$(dirname "$accessTokenFile")"
        chown -R "$user:$group" "$(dirname "$accessTokenFile")"
      '';
    };

    systemd.services.googlebird = {
      description = "googlebird Pleroma Bot";
      wants = [ "googlebird-config.service" ];
      path = with pkgs; [ googlebird ];
      environment = {
        SERVER_URL = cfg.server;
        ACCESS_TOKEN_PATH = cfg.accessTokenFile;
      };

      script = ''
        export ACCESS_TOKEN="$(cat "$ACCESS_TOKEN_PATH")"
        googlebird.py post
      '';

      unitConfig = {
        # Access token file must exist to run this service 
        ConditionPathExists = [ cfg.accessTokenFile ];
      };

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
      };
    };

    systemd.services.googlebird-reply = {
      description = "googlebird Pleroma Bot Reply Service";
      wants = [ "googlebird-config.service" ];
      wantedBy = [ "network-online.target" ];
      path = with pkgs; [ googlebird ];

      startLimitIntervalSec = 500;
      startLimitBurst = 5;

      environment = {
        SERVER_URL = cfg.server;
        ACCESS_TOKEN_PATH = cfg.accessTokenFile;
      };

      script = ''
        export ACCESS_TOKEN="$(cat "$ACCESS_TOKEN_PATH")"
        googlebird.py reply
      '';

      unitConfig = {
        # Access token file must exist to run this service 
        ConditionPathExists = [ cfg.accessTokenFile ];
      };

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;

        StartLimitIntervalSec = 0; # do not give up on restarting
        Restart = "always";
        RestartSec = 10;
      };
    };

    systemd.timers.googlebird = {
      wantedBy = [ "network-online.target" ];
      timerConfig.OnCalendar = cfg.postOnCalendar;
    };

    users.users = optionalAttrs (cfg.user == defaultUser) {
      ${defaultUser} = {
        group = cfg.group;
        isSystemUser = true;
      };
    };

    users.groups =
      optionalAttrs (cfg.group == defaultUser) { ${defaultUser} = { }; };
  };
}
