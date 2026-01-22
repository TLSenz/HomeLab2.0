{ config, pkgs, lib, ... }:
let
  role = lib.getEnv "NIXOS_CONFIG_ROLE";
in
{
  imports =
    (if role == "web" then [ ./modules/web.nix ./hardware-configuration ]
     else if role == "db"  then [ ./roles/db.nix ./hardware-configuration ]
     else if role == "ci"  then [ ./roles/ci.nix ./hardware-configuration ]
     else [ ./hardware-configuration ]);

  services.openssh.enable = true;
  networking = {
    hostName = "${role}";
    nameservers = ["192.168.1.76" "1.1.1.1"];
}
  users.users.worker = {
    isNormalUser = true;
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOEX55tH1gn4+Bsypr+2u5qwKmfOG68peFII4p1si7q/ thalium@cachyos-x8664" ];
  };
}
