{
  description = "NixOS Kiosk - LAN ETS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    brother-ql570-src = {
      url = "path:/var/lib/nixos-vendor/brother-ql570";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, brother-ql570-src }:
  let
    system = "x86_64-linux";

    brotherQl570Sources = {
      cupswrapper =
        brother-ql570-src + "/cupswrapper-ql570-src-1.1.1-1";

      lpr =
        brother-ql570-src + "/ql570lpr-1.0.1-0.i386";
    };
  in
  {
    nixosConfigurations.kiosk = nixpkgs.lib.nixosSystem {
      inherit system;

      specialArgs = {
        inherit nixpkgs brotherQl570Sources;
      };

      modules = [
        ./kiosk.nix
      ];
    };

    packages.${system}.iso =
      self.nixosConfigurations.kiosk.config.system.build.isoImage;
  };
}