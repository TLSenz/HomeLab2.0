{ config, pkgs, lib, ... }:
let
  role = lib.getEnv "NIXOS_CONFIG_ROLE";
in
{
  imports =
    (if role == "web" then [ ./modules/web.nix ]
     else if role == "db"  then [ ./roles/db.nix ]
     else if role == "ci"  then [ ./roles/ci.nix ]
     else [ ]);

  # shared stuff
  services.openssh.enable = true;
  users.users.youruser = {
    isNormalUser = true;
    initialPassword = "changeme";
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3…" ];
  };
}
