{ config, pkgs, ... }:

{
  imports = [
    ../modules/services/webserver.nix
  ];

  # Web server specific configuration
  services.nginx = {
    enable = true;
    recommendedOptimisation = true;
    recommendedGzipSettings = true;
    recommendedProxySettings = true;
    
    # Basic virtual host configuration
    virtualHosts."localhost" = {
      locations."/" = {
        root = "/var/www/html";
      };
    };
  };

  # Firewall configuration for web traffic
  networking.firewall.allowedTCPPorts = [ 80 443 ];

  # Additional packages for web server management
  environment.systemPackages = with pkgs; [
    curl
    wget
    certbot
  ];

  # Enable log rotation
  services.logrotate.settings.nginx = {
    files = "/var/log/nginx/*.log";
    frequency = "weekly";
    rotate = 4;
    compress = true;
    delaycompress = true;
    missingok = true;
    notifempty = true;
    create = "640 nginx adm";
    sharedscripts = true;
    postrotate = "[ ! -f /var/run/nginx.pid ] || kill -USR1 `cat /var/run/nginx.pid`";
  };
}