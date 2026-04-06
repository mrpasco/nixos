{
  description = "NixOS configuration with KDE Plasma Desktop";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs@{ self, nixpkgs, nixpkgs-unstable, home-manager, ... }:
    let
      system = "x86_64-linux";

      # Import user configuration
      userConfig = import ./user-config.nix;

      pkgs-unstable = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
      };
      
      # Function to create NixOS configuration for each host
      mkHost = hostname: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs hostname userConfig pkgs-unstable; };
        modules = [
          ./hosts/${hostname}/default.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "backup";
              extraSpecialArgs = { inherit inputs hostname userConfig pkgs-unstable; };
              users.${userConfig.username} = import ./home-manager;
            };
          }
        ];
      };
    in
    {
      # NixOS configurations for each host
      nixosConfigurations = {
        home = mkHost "home";
        work = mkHost "work";
      };
    };
}
