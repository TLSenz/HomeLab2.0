{ config, pkgs, ... }:

{
  imports = [
    ../modules/services/database.nix
  ];

  # PostgreSQL configuration
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_15;
    enableTCPIP = true;
    authentication = ''
      # TYPE  DATABASE        USER            ADDRESS                 METHOD
      local   all             all                                     trust
      host    all             all             127.0.0.1/32            md5
      host    all             all             ::1/128                 md5
    '';
    
    # Initial database setup
    initialScript = pkgs.writeText "init.sql" ''
      CREATE ROLE webapp WITH LOGIN PASSWORD 'changeme';
      CREATE DATABASE webapp OWNER webapp;
    '';
  };

  # Firewall for database access
  networking.firewall.allowedTCPPorts = [ 5432 ];

  # Database management tools
  environment.systemPackages = with pkgs; [
    postgresql_15
    pgadmin
  ];

  # Backup configuration for databases
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
    checkpoint_completion_target = 0.9;
    wal_buffers = "16MB";
    default_statistics_target = 100;
    random_page_cost = 1.1;
    effective_io_concurrency = 200;
  };
}