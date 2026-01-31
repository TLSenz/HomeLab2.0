{ config, pkgs, ... }:

{
  imports = [
    ../modules/services/webserver.nix
    ../modules/services/database.nix
  ];

  # Web server configuration
  services.nginx = {
    enable = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    
    virtualHosts."localhost" = {
      locations."/" = {
        root = "/var/www/html";
      };
      
      # Reverse proxy to application
      locations."/api/" = {
        proxyPass = "http://127.0.0.1:8080/";
        proxyWebsockets = true;
      };
    };
  };

  # PostgreSQL configuration
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_15;
    enableTCPIP = true;
    authentication = ''
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            md5
      host    all             all             ::1/128                 md5
    '';
    
    initialScript = pkgs.writeText "init.sql" ''
      CREATE ROLE webapp WITH LOGIN PASSWORD 'changeme';
      CREATE DATABASE webapp OWNER webapp;
    '';
  };

  # Firewall configuration
  networking.firewall.allowedTCPPorts = [ 80 443 5432 ];

  # Application packages
  environment.systemPackages = with pkgs; [
    curl
    wget
    certbot
    postgresql_15
    nodejs_20
    npm
  ];

  # Database backups
  services.postgresqlBackup = {
    enable = true;
    location = "/var/backups/postgresql";
    databases = [ "webapp" ];
    compression = "gzip";
    retentionDays = 30;
  };

  # Performance tuning
  services.postgresql.settings = {
    shared_buffers = "256MB";
    effective_cache_size = "1GB";
    maintenance_work_mem = "64MB";
  };

  # Log rotation for nginx
  services.logrotate.settings.nginx = {
    files = "/var/log/nginx/*.log";
    frequency = "weekly";
    rotate = 4;
    compress = true;
  };
}