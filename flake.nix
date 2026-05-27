{
  description = "NixOS Kiosk - LAN ETS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

  outputs = { self, nixpkgs }: {
    nixosConfigurations.kiosk = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit nixpkgs; };
      modules = [ ./kiosk.nix ];
    };

    packages.x86_64-linux.iso =
      self.nixosConfigurations.kiosk.config.system.build.isoImage;
  };
}