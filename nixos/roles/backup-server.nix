{ config, pkgs, ... }:

{
  # Backup server specific configuration
  
  # Restic backup service
  services.restic.backups = {
    main = {
      repository = "/var/backups/restic";
      paths = [
        "/home"
        "/etc"
        "/var/lib"
      ];
      passwordFile = config.sops.secrets.restic-password.path;
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
        "--keep-yearly 3"
      ];
    };
  };

  # Borgbackup for long-term storage
  services.borgbackup.jobs.main = {
    repository = "/var/backups/borg";
    paths = [
      "/home"
      "/etc"
      "/var/lib"
    ];
    encryption.mode = "repokey";
    encryption.passphrase = "changeme"; # This should be in secrets
    compression = "zstd,6";
    startAt = "daily";
    prune.keep = {
      daily = 7;
      weekly = 4;
      monthly = 12;
      yearly = 3;
    };
  };

  # Monitoring for backup operations
  services.prometheus.exporters.node = {
    enable = true;
    enabledCollectors = [ "systemd" "diskstats" "netstat" ];
    port = 9100;
  };

  # Grafana for backup monitoring
  services.grafana = {
    enable = true;
    settings.server = {
      http_port = 3000;
      domain = "localhost";
    };
  };

  # Firewall configuration
  networking.firewall.allowedTCPPorts = [ 3000 9100 ];

  # Backup management packages
  environment.systemPackages = with pkgs; [
    restic
    borgbackup
    htop
    iotop
    rsync
  ];

  # Create backup directories
  systemd.tmpfiles.rules = [
    "d /var/backups/restic 0700 root root -"
    "d /var/backups/borg 0700 root root -"
    "d /var/backups/archives 0755 root root -"
  ];

  # Log rotation for backup logs
  services.logrotate.settings.backup = {
    files = "/var/log/backup/*.log";
    frequency = "weekly";
    rotate = 4;
    compress = true;
  };
}