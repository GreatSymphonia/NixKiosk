{ pkgs
, nixpkgs
, brotherQl570Sources
, ...
}:

let
  brotherQl570 =
    pkgs.callPackage ./pkgs/brother-ql570 {
      inherit brotherQl570Sources;
    };

  printerName = "QL-570";
  printerModel = "brother_ql570_printer_en.ppd";
  printerPageSize = "62x29";

  kioskUrl = "https://forms.cloud.microsoft/Pages/ResponsePage.aspx?id=oyeMGL-GiEmclAJadfzw0RXX5hvDK6FBphzqQ6blWrJURE5PUTdDR0laM0VLUlJETlhKMEdJSEYxWS4u";

  firefoxKiosk = pkgs.writeShellScript "firefox-session" ''
    set -eu

    PROFILE_DIR="$HOME/firefox-session-profile"

    #
    # Fresh Firefox session on every launch.
    #
    rm -rf "$PROFILE_DIR"
    mkdir -p "$PROFILE_DIR"

    cat > "$PROFILE_DIR/user.js" <<EOF
  user_pref("browser.shell.checkDefaultBrowser", false);
  user_pref("browser.startup.homepage", "${kioskUrl}");
  user_pref("browser.sessionstore.resume_from_crash", false);
  user_pref("browser.sessionstore.max_resumed_crashes", 0);
  user_pref("browser.warnOnQuit", false);
  user_pref("browser.tabs.warnOnClose", false);
  user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
  user_pref("datareporting.policy.dataSubmissionEnabled", false);

  user_pref("print.always_print_silent", false);
  user_pref("print_printer", "${printerName}");
  user_pref("print.save_print_settings", true);
  EOF

    export MOZ_ENABLE_WAYLAND=1

    exec ${pkgs.firefox}/bin/firefox \
      --profile "$PROFILE_DIR" \
      "${kioskUrl}"
  '';
in
{
  imports = [
    "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix"
  ];

  nixpkgs.config.allowUnfree = true;

  isoImage.edition = "kiosk-lanets";
  isoImage.squashfsCompression = "zstd -Xcompression-level 6";
  isoImage.volumeID = "KIOSK-LANETS";

  boot.kernelParams = [
    "copytoram"
  ];

  networking.hostName = "kiosk-lanets";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Toronto";
  i18n.defaultLocale = "fr_CA.UTF-8";

  users.users.kiosk = {
    isNormalUser = true;
    extraGroups = [
      "video"
      "input"
      "networkmanager"
    ];

    # ISO kiosk local, pas destiné à être un compte interactif sécurisé.
    password = "";
  };

  #
  # Graphiques / Wayland
  #
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [
    "modesetting"
    "vesa"
  ];

  programs.dconf.enable = true;

  xdg.portal = {
    enable = true;
    wlr.enable = true;
  };

  xdg.portal.config.common.default = "*";

  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-color-emoji
    dejavu_fonts
    freefont_ttf
  ];

  fonts.fontconfig.enable = true;

  #
  # Impression / CUPS
  #
  services.printing = {
    enable = true;
    webInterface = true;

    drivers = [
      brotherQl570
    ];
  };

  #
  # Compatibilité Brother.
  #
  # Plusieurs vieux scripts/binaires Brother cherchent encore directement :
  #
  #   /opt/brother/PTouch/ql570/...
  #
  # même si le package est dans /nix/store.
  #
  systemd.tmpfiles.rules = [
    "d /opt 0755 root root - -"
    "L+ /opt/brother - - - - ${brotherQl570}/opt/brother"
  ];

  #
  # Configuration automatique de la première Brother QL-570 détectée.
  #
  # On évite de hardcoder :
  #
  #   usb://Brother/QL-570?serial=...
  #
  # Le service cherche plutôt la première imprimante USB QL-570 disponible.
  #
  systemd.services.configure-ql570-printer = {
    description = "Configure first detected Brother QL-570 CUPS queue";
    wantedBy = [ "multi-user.target" ];
    after = [
      "cups.service"
      "systemd-udev-settle.service"
    ];
    wants = [
      "cups.service"
      "systemd-udev-settle.service"
    ];

    path = [
      pkgs.cups
      pkgs.coreutils
      pkgs.gnugrep
      pkgs.gawk
      pkgs.gnused
    ];

    serviceConfig = {
      Type = "oneshot";

      # Si l'imprimante n'est pas branchée au boot, on réessaie.
      Restart = "on-failure";
      RestartSec = "5s";
    };

    script = ''
      set -eu

      echo "Looking for Brother QL-570 USB printer..."

      PRINTER_URI="$(
        lpinfo -v \
          | grep -m1 '^direct usb://Brother/QL-570' \
          | awk '{print $2}'
      )"

      if [ -z "$PRINTER_URI" ]; then
        echo "No Brother QL-570 USB printer found yet."
        exit 1
      fi

      echo "Found Brother QL-570 at: $PRINTER_URI"

      lpadmin \
        -p ${printerName} \
        -E \
        -v "$PRINTER_URI" \
        -m '${printerModel}' \
        -o PageSize=${printerPageSize} \
        -o BrCutAtEnd=ON \
        -o BrCutLabel=1

      lpoptions -d ${printerName}

      cupsaccept ${printerName}
      cupsenable ${printerName}

      echo "Configured CUPS queue ${printerName} with URI $PRINTER_URI"
    '';
  };

  #
  # Firefox kiosk via Cage
  #
  services.cage = {
    enable = true;
    user = "kiosk";
    program = "${firefoxKiosk}";
  };

  systemd.services."cage-tty1" = {
    after = [
      "network-online.target"
      "cups.service"
      "configure-ql570-printer.service"
    ];

    wants = [
      "network-online.target"
      "cups.service"
      "configure-ql570-printer.service"
    ];

    serviceConfig = {
      Restart = "always";
      RestartSec = "3s";
    };
  };

  #
  # Accès admin/debug
  #
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
  };

  users.users.kiosk.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ+RLnMHSHLIy8iHgBY0Xkiv3u1zpXzhuXLOwWSvswuR louis@nixos"
  ];

  environment.systemPackages = with pkgs; [
    firefox
    cage
    cups
    usbutils
    vim
  ];

  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  system.stateVersion = "26.05";
}
