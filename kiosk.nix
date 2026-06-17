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
      ${pkgs.firefox}/bin/firefox \
        --kiosk \
        https://ctfd.summercamp.dciets.com/scoreboard &
      FIREFOX_PID=$!

      while kill -0 "$FIREFOX_PID" 2>/dev/null; do
        sleep 10
        ${pkgs.wtype}/bin/wtype -k F5
      done

      wait "$FIREFOX_PID"
    ''}";
  };

  systemd.services."cage-tty1".serviceConfig = {
    Restart = "always";
    RestartSec = "3s";
  };

  environment.systemPackages = with pkgs; [
    firefox
    cage
    wtype
  ];

  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  users.users.kiosk.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ+RLnMHSHLIy8iHgBY0Xkiv3u1zpXzhuXLOwWSvswuR louis@nixos"
  ];

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "fr_CA.UTF-8";

  system.stateVersion = "25.11";
}