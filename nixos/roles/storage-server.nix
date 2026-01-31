{ config, pkgs, ... }:

{
  # Storage server specific configuration
  
  # File sharing services
  services.samba = {
    enable = true;
    securityType = "user";
    extraConfig = ''
      workgroup = WORKGROUP
      server string = Storage Server
      netbios name = storage
      security = user
      map to guest = bad user
    '';
    
    shares = {
      public = {
        path = "/srv/public";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0664";
        "directory mask" = "0775";
      };
      
      private = {
        path = "/srv/private";
        browseable = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "create mask" = "0660";
        "directory mask" = "0770";
      };
    };
  };

  # NFS server
  services.nfs.server = {
    enable = true;
    exports = ''
      /srv/export 192.168.1.0/24(rw,sync,no_subtree_check,no_root_squash)
    '';
  };

  # Firewall configuration
  networking.firewall.allowedTCPPorts = [ 2049 445 139 ];
  networking.firewall.allowedUDPPorts = [ 137 138 2049 ];

  # Storage management packages
  environment.systemPackages = with pkgs; [
    nfs-utils
    cifs-utils
    htop
    iotop
  ];

  # Create storage directories
  systemd.tmpfiles.rules = [
    "d /srv/public 0775 root users -"
    "d /srv/private 0770 root users -"
    "d /srv/export 0755 root root -"
  ];

  # Additional user for storage access
  users.users.storage = {
    isNormalUser = true;
    description = "Storage service user";
    initialPassword = "changeme";
    group = "users";
  };
}