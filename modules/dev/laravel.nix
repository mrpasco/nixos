{ config, lib, pkgs, userConfig, ... }:

let
  php = pkgs.php83.withExtensions ({ enabled, all }: enabled ++ (with all; [
    bcmath
    curl
    gd
    intl
    mbstring
    mysqli
    pdo_mysql
    zip
  ]));
in {
  # PHP 8.3 with Laravel-required extensions
  environment.systemPackages = [
    php
    php.packages.composer
    pkgs.nodejs_22
  ];

  # MySQL 8
  services.mysql = {
    enable = true;
    package = pkgs.mysql80;
    ensureDatabases = [ "moneycue" ];
    ensureUsers = [{
      name = userConfig.username;
      ensurePermissions."moneycue.*" = "ALL PRIVILEGES";
    }];
    settings.mysqld = {
      bind-address = "127.0.0.1";     # Localhost only — never expose to LAN
      skip_name_resolve = true;        # Skip reverse DNS lookups — prevents slow connection hangs
    };
  };

  # After every MySQL start (including after nixos-rebuild switch), ensure the dev user
  # has a password so Adminer can authenticate. mysql_native_password is used because
  # the default auth_socket plugin blocks password-based logins entirely.
  # This is local dev only — the password is stored in secrets/mysql-password.txt.
  systemd.services.mysql-set-dev-password = {
    description = "Set password for local MySQL dev user";
    wantedBy    = [ "multi-user.target" ];
    after       = [ "mysql.service" ];
    requires    = [ "mysql.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = "root";
    };
    script = ''
      password=$(cat /home/${userConfig.username}/nixos-config/secrets/mysql-password.txt)
      ${pkgs.mysql80}/bin/mysql -e \
        "ALTER USER '${userConfig.username}'@'localhost' IDENTIFIED WITH mysql_native_password BY '$password'; FLUSH PRIVILEGES;"
    '';
  };

  # Adminer (database UI) via nginx on http://localhost:8080
  services.phpfpm.pools.adminer = {
    user = userConfig.username;
    group = "users";
    phpPackage = php;
    phpOptions = ''
      mysql.default_socket     = /run/mysqld/mysqld.sock
      mysqli.default_socket    = /run/mysqld/mysqld.sock
      pdo_mysql.default_socket = /run/mysqld/mysqld.sock
      session.cookie_secure    = 0
    '';
    settings = {
      "listen.owner" = config.services.nginx.user;
      "pm" = "dynamic";
      "pm.max_children" = 20;
      "pm.start_servers" = 2;
      "pm.min_spare_servers" = 2;
      "pm.max_spare_servers" = 10;
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts.adminer = {
      listen = [{ addr = "127.0.0.1"; port = 8080; ssl = false; }];
      root = "${pkgs.adminer}";
      locations."/" = {
        index = "adminer.php";
      };
      locations."~ \\.php$" = {
        fastcgiParams = {
          SCRIPT_FILENAME = "$document_root$fastcgi_script_name";
          HTTPS = "off";
        };
        extraConfig = ''
          fastcgi_pass unix:${config.services.phpfpm.pools.adminer.socket};
          fastcgi_read_timeout 300;
          include ${pkgs.nginx}/conf/fastcgi_params;
        '';
      };
    };
  };
}
