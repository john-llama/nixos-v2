{
  config,
  lib,
  pkgs,
  ...
}:

# Jellyfin media server streaming ~/Media to phones and TVs on the LAN, transcoding on the NVIDIA GPU.
let
  cfg = config.jellyfin;
  group = config.users.users.${cfg.user}.group;
  # Jellyfin's default HTTP port; the NixOS module doesn't expose it.
  url = "http://localhost:8096";

  # Starts the server if needed, waits for its web UI, then opens it.
  openJellyfin = pkgs.writeShellApplication {
    name = "jellyfin-open";
    runtimeInputs = [
      pkgs.systemd
      pkgs.curl
      pkgs.libnotify
      pkgs.xdg-utils
    ];
    text = ''
      # Allowed without a password prompt by the polkit rule below.
      systemctl start jellyfin.service

      for _ in $(seq 1 60); do
        if curl -fsS -o /dev/null "${url}/health"; then
          exec xdg-open "${url}"
        fi
        sleep 0.5
      done
      notify-send --app-name=Jellyfin "Jellyfin didn't start" "Check: journalctl -u jellyfin"
      exit 1
    '';
  };

  # X-Windowless: it opens a browser tab rather than its own window, so the
  # Quickshell launcher shows no launching spinner for it.
  desktopItem = pkgs.makeDesktopItem {
    name = "jellyfin";
    desktopName = "Jellyfin";
    comment = "Start the media server and open its web interface";
    exec = "jellyfin-open";
    icon = "${pkgs.jellyfin-web}/share/jellyfin-web/favicons/touchicon512.png";
    categories = [
      "AudioVideo"
      "Video"
      "X-Windowless"
    ];
  };
in
{
  options.jellyfin = {
    # Home directories are 0700, so Jellyfin runs as the owner to read media there.
    user = lib.mkOption {
      type = lib.types.str;
      description = "User Jellyfin runs as; must be able to read the media folders.";
    };
    mediaPath = lib.mkOption {
      type = lib.types.str;
      default = "${config.users.users.${cfg.user}.home}/Media";
      defaultText = lib.literalExpression ''"''${home}/Media"'';
      description = "Root folder holding one subfolder per Jellyfin library.";
    };
    autoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start Jellyfin at boot; otherwise its desktop entry starts it on demand.";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Jellyfin's web and discovery ports to the local network.";
    };
  };

  config = {
    services.jellyfin = {
      enable = true;
      inherit (cfg) user openFirewall;
      inherit group;

      hardwareAcceleration = {
        enable = true;
        type = "nvenc";
        device = "/dev/nvidia0";
      };
      # Keep transcoding settings here; dashboard edits are reset on restart.
      forceEncodingConfig = true;
      transcoding = {
        enableHardwareEncoding = true;
        # Everything the GTX 1650's NVDEC can decode.
        hardwareDecodingCodecs = {
          h264 = true;
          hevc = true;
          hevc10bit = true;
          mpeg2 = true;
          vc1 = true;
          vp8 = true;
          vp9 = true;
        };
        hardwareEncodingCodecs.hevc = true;
      };
    };

    # The NixOS module starts it at boot; without autoStart it waits for the desktop entry.
    systemd.services.jellyfin.wantedBy = lib.mkIf (!cfg.autoStart) (lib.mkForce [ ]);

    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "${cfg.user}" &&
            action.lookup("unit") == "jellyfin.service")
          return polkit.Result.YES;
      });
    '';

    users.users.${cfg.user}.packages = [
      openJellyfin
      desktopItem
    ];

    systemd.services.jellyfin.serviceConfig = {
      # NVENC also needs the control and memory devices next to /dev/nvidia0.
      DeviceAllow = [
        "/dev/nvidiactl rw"
        "/dev/nvidia-uvm rw"
        "/dev/nvidia-uvm-tools rw"
        "/dev/nvidia-modeset rw"
      ];
      # Hide the rest of /home; expose only the media folder, read-only.
      ProtectHome = "tmpfs";
      BindReadOnlyPaths = [ cfg.mediaPath ];
    };

    # One folder per Jellyfin library; point each library at its folder in the web UI.
    systemd.tmpfiles.rules = map (dir: "d '${cfg.mediaPath}/${dir}' 0755 ${cfg.user} ${group} -") [
      ""
      "TV Shows"
      "Movies"
    ];
  };
}
