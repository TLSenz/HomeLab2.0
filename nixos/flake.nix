{
  description = "Dynamic Webhook-Driven NixOS Fleet";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      # 1. Define your library of available service modules
      serviceLibrary = {
        web      = ./modules/services/webserver.nix;
        db       = ./modules/services/database.nix;
      };

      # 2. Define your library of available roles
      roleLibrary = {
        web-server      = ./roles/web-server.nix;
        database-server  = ./roles/database-server.nix;
        full-stack       = ./roles/full-stack.nix;
        storage-server   = ./roles/storage-server.nix;
        backup-server    = ./roles/backup-server.nix;
      };

      # 3. Load the configuration requested by the Webhook (via the Action)
      # If the file doesn't exist yet (local dev), default to empty lists
      deploymentConfig = 
        if builtins.pathExists ./deployment-config.json 
        then builtins.fromJSON (builtins.readFile ./deployment-config.json)
        else { role = null; services = []; };

      requestedRole = deploymentConfig.role or null;
      requestedServices = deploymentConfig.services or [];

      # 4. Helper to create the system
      mkHost = hostName: nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          # Local hardware config from the target machine
          /etc/nixos/hardware-configuration.nix 

          # The machine's base configuration file
          ./hosts/${hostName}/configuration.nix

          # Shared settings for all machines
          ./common/global.nix

          # Dynamic configuration based on role or services
        ] ++ 
        # Add role if specified
        (if (requestedRole != null && roleLibrary ? ${requestedRole}) 
         then [ roleLibrary.${requestedRole} ]
         else []) ++
        # Add individual services if specified (fallback or mixed mode)
        (map (svc: serviceLibrary.${svc}) requestedServices);
      };
    in
    {
      # These names match the 'config' field in your webhook
      nixosConfigurations = {
        "node-a" = mkHost "node-a";
        "node-b" = mkHost "node-b";
        "backup-server" = mkHost "backup-server";
      };
    };
}
