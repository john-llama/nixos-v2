{
  config,
  lib,
  pkgs,
  ...
}:

# React Native (bare CLI) Android development: Android Studio manages a writable SDK
# in the user's home, which Gradle can extend with whatever SDK/NDK versions a project pins.
let
  cfg = config.reactNative;
  sdkPath = "${config.users.users.${cfg.user}.home}/Android/Sdk";
  # Metro bundler; physical devices on Wi-Fi debugging fetch the JS bundle from here.
  metroPort = 8081;

  # Hyprland is a tiling WM; without this Java AWT windows render blank.
  androidStudio = (pkgs.androidStudioPackages.override { tiling_wm = true; }).stable;
in
{
  options.reactNative = {
    user = lib.mkOption {
      type = lib.types.str;
      description = "User who builds React Native apps; owns the Android SDK.";
    };
    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Metro's port so devices on the LAN can load the bundle.";
    };
  };

  config = {
    users.users.${cfg.user}.packages = with pkgs; [
      androidStudio # SDK manager, device manager, emulator UI
      watchman # file watcher Metro prefers over its node fallback
    ];

    home-manager.users.${cfg.user}.home = {
      sessionVariables = {
        ANDROID_HOME = sdkPath;
        # Legacy name some Gradle plugins still read.
        ANDROID_SDK_ROOT = sdkPath;
        # React Native's Gradle plugin requires JDK 17.
        JAVA_HOME = "${pkgs.jdk17}/lib/openjdk";
      };
      packages = [ pkgs.jdk17 ];
      # Use the SDK's adb (not pkgs.android-tools) so Studio and the CLI share one adb server.
      sessionPath = [
        "${sdkPath}/platform-tools"
        "${sdkPath}/emulator"
        "${sdkPath}/cmdline-tools/latest/bin"
      ];
    };

    # Gradle runs SDK binaries (aapt2, cmake, NDK clang, the emulator) from the terminal,
    # outside Android Studio's FHS env; these are the libraries Studio's wrapper provides them.
    programs.nix-ld.libraries = with pkgs; [
      # Gradle and aapt
      ncurses5
      e2fsprogs
      # emulator
      alsa-lib
      dbus
      expat
      fontconfig
      freetype
      libbsd
      libpulseaudio
      libuuid
      libx11
      libxcb
      libxkbcommon
      libxcb-wm
      libxcb-render-util
      libxcb-keysyms
      libxcb-image
      libxcb-cursor
      libice
      libsm
      libxext
      libxi
      libxrender
      libxtst
      libxrandr
      libxkbfile
      libxcomposite
      libxcursor
      libxdamage
      libxfixes
      libGL
      libdrm
      libpng
      nspr
      nss_latest
      wayland
      # React Native DevTools (`j` in Metro), a prebuilt Electron app fetched by dotslash
      glib
      gtk3
      pango
      cairo
      at-spi2-core # atk, atk-bridge, atspi
      cups
      libgbm
      systemd # libudev
    ];

    networking.firewall.allowedTCPPorts = lib.mkIf cfg.openFirewall [ metroPort ];
  };
}
