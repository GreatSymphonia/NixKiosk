{ pkgs, lib, nixpkgs, ... }:
{
  imports = [ "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix" ];

  isoImage.edition = "kiosk-lanets";
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";
  isoImage.volumeID = "KIOSK-LANETS";

  boot.kernelParams = [ "copytoram" ];

  # Drivers vidéo
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "modesetting" "vesa" ];

  networking.hostName = "kiosk-lanets";
  networking.networkmanager.enable = true;

  users.users.kiosk = {
    isNormalUser = true;
    extraGroups = [ "video" "input" ];
    password = "";
  };

  xdg.portal.config.common.default = "*";

  # Polices
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    dejavu_fonts
    freefont_ttf
  ];
  fonts.fontconfig.enable = true;

  # Wayland
  programs.dconf.enable = true;
  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };

  services.cage = {
    enable = true;
    user = "kiosk";
    program = "${pkgs.writeShellScript "firefox-kiosk" ''
      exec ${pkgs.firefox}/bin/firefox \
        --kiosk \
        https://kiosk.lanets.ca
    ''}";
  };

  environment.systemPackages = with pkgs; [
    firefox
    cage
  ];

  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "fr_CA.UTF-8";

  system.stateVersion = "25.11";
}