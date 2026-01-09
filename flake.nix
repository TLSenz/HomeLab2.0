{
  description = "Re-configure existing NixOS boxes";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      system = "x86_64-linux";
    in
    {
      nixosConfigurations.default = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit (nixpkgs) lib; };
        modules = [ ./nixos/configuration.nix ];   # your new config
      };
    };
}
