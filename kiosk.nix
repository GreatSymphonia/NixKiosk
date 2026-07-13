{ pkgs
, lib
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
  printerUri = "usb://Brother/QL-570?serial=D3Z971952";
  printerModel = "brother_ql570_printer_en.ppd";
  printerPageSize = "62x29";

  kioskUrl = "https://ctfd.summercamp.dciets.com/scoreboard";

  firefoxKiosk = pkgs.writeShellScript "firefox-kiosk" ''
    set -eu

    PROFILE_DIR="$HOME/firefox-kiosk-profile"

    mkdir -p "$PROFILE_DIR"

    cat > "$PROFILE_DIR/user.js" <<EOF
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage", "${kioskUrl}");
user_pref("browser.sessionstore.resume_from_crash", false);
user_pref("toolkit.telemetry.reportingpolicy.firstRun", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("print.always_print_silent", true);
user_pref("print_printer", "${printerName}");
EOF

    export MOZ_ENABLE_WAYLAND=1

    ${pkgs.firefox}/bin/firefox \
      --profile "$PROFILE_DIR" \
      --kiosk \
      "${kioskUrl}" &

    FIREFOX_PID=$!

    while kill -0 "$FIREFOX_PID" 2>/dev/null; do
      sleep 10
      ${pkgs.wtype}/bin/wtype -k F5 || true
    done

    wait "$FIREFOX_PID"
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
    password = "";
  };

  #
  # Graphics / display
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
  # Printing
  #
  services.printing = {
    enable = true;
    webInterface = true;

    drivers = [
      brotherQl570
    ];
  };

  #
  # Compatibility for old Brother binaries/scripts.
  #
  systemd.tmpfiles.rules = [
    "d /opt 0755 root root - -"
    "L+ /opt/brother - - - - ${brotherQl570}/opt/brother"
  ];

  #
  # Declaratively create the CUPS queue at boot.
  #
  systemd.services.configure-ql570-printer = {
    description = "Configure Brother QL-570 CUPS queue";
    wantedBy = [ "multi-user.target" ];
    after = [ "cups.service" ];
    wants = [ "cups.service" ];

    path = [
      pkgs.cups
      pkgs.coreutils
    ];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };

    script = ''
      set -eu

      lpadmin \
        -p ${printerName} \
        -E \
        -v '${printerUri}' \
        -m '${printerModel}' \
        -o PageSize=${printerPageSize} \
        -o BrCutAtEnd=ON \
        -o BrCutLabel=1

      lpoptions -d ${printerName}

      cupsaccept ${printerName}
      cupsenable ${printerName}
    '';
  };

  #
  # Cage + Firefox kiosk
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
  # Debug/admin access
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
    wtype
    cups
    usbutils
    vim
    git
  ];

  services.logind.settings.Login = {
    IdleAction = "ignore";
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
  };

  system.stateVersion = "26.05";
}