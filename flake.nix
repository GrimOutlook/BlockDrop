{
  description = "Block Drop development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            android_sdk.accept_license = true;
          };
        };

        # Keep in sync with android/app/build.gradle.kts (ndkVersion).
        ndkVersion = "28.2.13676358";

        androidComposition = pkgs.androidenv.composeAndroidPackages {
          platformVersions = [ "34" "35" "36" ];
          buildToolsVersions = [ "34.0.0" "35.0.0" ];
          cmakeVersions = [ "3.22.1" ];
          includeNDK = true;
          ndkVersions = [ ndkVersion ];
          includeEmulator = false;
          includeSystemImages = false;
        };

        androidSdk = androidComposition.androidsdk;

        # Native deps for `flutter build linux` / `flutter run -d linux`,
        # mirrors the apt-get list in .github/workflows/release.yml.
        linuxDesktopDeps = with pkgs; [
          clang
          cmake
          ninja
          pkg-config
          gtk3
          xz
          gst_all_1.gstreamer
          gst_all_1.gst-plugins-base
          gst_all_1.gst-plugins-good
          gst_all_1.gst-plugins-bad
        ];
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            jdk17
            androidSdk
            git
            unzip
            which
          ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux linuxDesktopDeps;

          JAVA_HOME = pkgs.jdk17.home;
          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";

          shellHook = ''
            # Use the pinned Flutter checked out as a git submodule (see
            # .gitmodules and the CI workflows) rather than a nixpkgs-provided
            # Flutter, so the local SDK version always matches CI exactly.
            export PATH="$PWD/flutter/bin:$PATH"

            if [ ! -x "$PWD/flutter/bin/flutter" ]; then
              echo "warning: flutter submodule not checked out — run: git submodule update --init" >&2
            fi

            echo "Block Drop dev shell ready (jdk17, Android SDK, NDK ${ndkVersion})"
          '';
        };
      });
}
