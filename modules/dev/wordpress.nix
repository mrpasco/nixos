{ config, lib, pkgs, userConfig, ... }:

let
  cfg = config.services.wordpressDev;

  php = pkgs.php83.withExtensions ({ enabled, all }: enabled ++ (with all; [
    bcmath
    curl
    exif
    gd
    intl
    mbstring
    mysqli
    pdo_mysql
    zip
  ]));

  mkPool = site: lib.nameValuePair "wp-${site}" {
    user = userConfig.username;
    group = "users";
    phpPackage = php;
    phpOptions = ''
      mysql.default_socket     = /run/mysqld/mysqld.sock
      mysqli.default_socket    = /run/mysqld/mysqld.sock
      pdo_mysql.default_socket = /run/mysqld/mysqld.sock
    '';
    settings = {
      "listen.owner" = userConfig.username;
      "listen.group" = "users";
      "pm" = "dynamic";
      "pm.max_children" = 5;
      "pm.start_servers" = 1;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
    };
  };

  mkVhost = site: lib.nameValuePair "${site}.test" {
    root = "/home/${userConfig.username}/Dev/${site}";
    listen = [{ addr = "127.0.0.1"; port = 80; ssl = false; }];
    locations."/" = {
      index = "index.php index.html";
      extraConfig = ''
        try_files $uri $uri/ /index.php?$args;
      '';
    };
    locations."~ \.php$" = {
      fastcgiParams = {
        SCRIPT_FILENAME = "$document_root$fastcgi_script_name";
      };
      extraConfig = ''
        fastcgi_pass unix:${config.services.phpfpm.pools."wp-${site}".socket};
        fastcgi_read_timeout 300;
        include ${pkgs.nginx}/conf/fastcgi_params;
      '';
    };
  };

in {
  options.services.wordpressDev = {
    enable = lib.mkEnableOption "WordPress development environment";
    sites = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        List of WordPress site names. Each site maps to ~/Dev/<name>/
        with its own MySQL database (wp_<name>) and nginx vhost at http://<name>.test.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ php php.packages.composer pkgs.wp-cli ];

    # MySQL: one database per site, all granted to the dev user
    services.mysql = {
      enable = true;
      package = lib.mkDefault pkgs.mysql80;
      ensureDatabases = map (site: "wp_${site}") cfg.sites;
      ensureUsers = [{
        name = userConfig.username;
        ensurePermissions = lib.listToAttrs (map (site: {
          name = "wp_${site}.*";
          value = "ALL PRIVILEGES";
        }) cfg.sites);
      }];
      settings.mysqld.bind-address = lib.mkDefault "127.0.0.1";
    };

    # One PHP-FPM pool per site, running as the dev user
    services.phpfpm.pools = lib.listToAttrs (map mkPool cfg.sites);

    # Nginx: run as dev user so it can read ~/Dev/, one vhost per site
    services.nginx = {
      enable = true;
      user = lib.mkDefault userConfig.username;
      group = lib.mkDefault "users";
      virtualHosts = lib.listToAttrs (map mkVhost cfg.sites);
    };

    # ProtectHome=true in nginx and php-fpm systemd units blocks ~/Dev/ even
    # when the processes run as the dev user — disable for local development.
    # Also sets up auth_socket for the MySQL dev user after each boot.
    systemd.services = lib.mkMerge (
      [
        { nginx.serviceConfig.ProtectHome = lib.mkForce false; }
        {
          wordpress-dev-db-auth = {
            description = "Configure MySQL socket auth for WordPress dev user";
            after = [ "mysql.service" ];
            requires = [ "mysql.service" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
            };
            script = ''
              ${config.services.mysql.package}/bin/mysql \
                --socket=/run/mysqld/mysqld.sock -u root -e \
                "ALTER USER '${userConfig.username}'@'localhost' IDENTIFIED WITH auth_socket;"
            '';
          };
        }
      ]
      ++ map (site: { "phpfpm-wp-${site}".serviceConfig.ProtectHome = lib.mkForce false; }) cfg.sites
    );

    # Resolve <site>.test to localhost
    networking.hosts."127.0.0.1" = map (site: "${site}.test") cfg.sites;
  };
}
