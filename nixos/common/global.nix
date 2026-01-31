{ config, pkgs, ... }:

{
  # Standard users
  users.users.worker = {
    isNormalUser = true;
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [ 
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEX55tH1gn4+Bsypr+2u5qwKmfOG68peFII4p1si7q/ thalium@cachyos-x8664" 
    ];
  };

  # SSH configuration
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";

  # Tailscale
  services.tailscale.enable = true;

  # Common packages
  environment.systemPackages = with pkgs; [
    vim
    git
    curl
    wget
  ];

  # Networking defaults
  networking.nameservers = ["192.168.1.76" "1.1.1.1"];

  # Security settings
  security.sudo.wheelNeedsPassword = false;
}