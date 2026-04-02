{ config, lib, pkgs, userConfig, ... }:

let
  php = pkgs.php83.withExtensions ({ enabled, all }: enabled ++ (with all; [
    bcmath
    curl
    gd
    intl
    mbstring
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
    settings.mysqld.bind-address = "127.0.0.1";  # Localhost only — never expose to LAN
  };

  # Adminer (database UI) via nginx on http://localhost:8080
  services.phpfpm.pools.adminer = {
    user = userConfig.username;
    group = "users";
    phpPackage = php;
    phpOptions = ''
      mysql.default_socket    = /run/mysqld/mysqld.sock
      mysqli.default_socket   = /run/mysqld/mysqld.sock
      pdo_mysql.default_socket = /run/mysqld/mysqld.sock
    '';
    settings = {
      "listen.owner" = config.services.nginx.user;
      "pm" = "dynamic";
      "pm.max_children" = 5;
      "pm.start_servers" = 1;
      "pm.min_spare_servers" = 1;
      "pm.max_spare_servers" = 3;
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
        };
        extraConfig = ''
          fastcgi_pass unix:${config.services.phpfpm.pools.adminer.socket};
          include ${pkgs.nginx}/conf/fastcgi_params;
        '';
      };
    };
  };
}
