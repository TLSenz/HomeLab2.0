{ config, pkgs, ... }:

{
  imports = [
    # Hardware configuration should be imported from the target machine
    # /etc/nixos/hardware-configuration.nix
  ];

  # Machine-specific settings
  networking.hostName = "node-b";
  time.timeZone = "UTC";

  # This machine's specific configuration
  # Add any node-b specific services or settings here
}