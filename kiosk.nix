{ pkgs, lib, nixpkgs, ... }:

{
  imports = [ "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix" ];

  isoImage.squashfsCompression = "zstd -Xcompression-level 6";
  isoImage.isoName = "nixos-kiosk-lanets.iso";

  boot.kernelParams = [ "copytoram" ];

  networking.hostName = "kiosk-lanets";
  networking.networkmanager.enable = true;

  users.users.kiosk = {
    isNormalUser = true;
    extraGroups = [ "video" "input" ];
    password = "";
  };

  services.cage = {
    enable = true;
    user = "kiosk";
    program = "${pkgs.chromium}/bin/chromium ${lib.concatStringsSep " " [
      "--kiosk"
      "--no-first-run"
      "--disable-infobars"
      "--noerrdialogs"
      "--disable-translate"
      "--disable-features=TranslateUI"
      "--check-for-update-interval=31536000"
      "https://kiosk.lanets.ca"
    ]}";
  };

  environment.systemPackages = with pkgs; [
    chromium
    cage
  ];

  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  powerManagement.enable = false;

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "fr_CA.UTF-8";

  system.stateVersion = "25.11";
}