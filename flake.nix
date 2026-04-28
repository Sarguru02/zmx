{
  description = "zmx - session persistence for terminal processes";

  inputs = {
    zig2nix.url = "github:Cloudef/zig2nix";
  };

  outputs =
    { zig2nix, ... }:
    let
      flake-utils = zig2nix.inputs.flake-utils;
    in
    (flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (
      system:
      let
        env = zig2nix.outputs.zig-env.${system} {
          zig = zig2nix.outputs.packages.${system}.zig-0_15_2;
        };
        isLinux = builtins.elem system [ "x86_64-linux" "aarch64-linux" ];
      in
      with builtins;
      with env.pkgs.lib;
      let
        # Mock xcrun/xcode-select for Zig's SDK detection in sandbox
        darwinBuildTools = optionals (!isLinux) [
          (env.pkgs.writeShellScriptBin "xcode-select" ''
            if [ "$1" = "--print-path" ]; then
              echo "${env.pkgs.apple-sdk}"
              exit 0
            fi
            exit 1
          '')
          (env.pkgs.writeShellScriptBin "xcrun" ''
            if [ "$1" = "--sdk" ] && [ "$3" = "--show-sdk-path" ]; then
              echo "${env.pkgs.apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
              exit 0
            fi
            exit 1
          '')
        ];

        zmx-package = (env.package {
          src = cleanSource ./.;
          zigBuildFlags = [ "-Doptimize=ReleaseSafe" ];
          zigPreferMusl = isLinux;
        }).overrideAttrs (finalAttrs: prevAttrs: {
          # Override ZIG_GLOBAL_CACHE_DIR after zigSetGlobalCacheDir hook runs
          # but before postConfigure symlinks deps. Keeps cache in build dir
          # to avoid RenameAcrossMountPoints on macOS (/tmp vs build dir).
          preConfigure = (prevAttrs.preConfigure or "") + ''
            export ZIG_GLOBAL_CACHE_DIR="$PWD/.zig-cache"
            mkdir -p "$ZIG_GLOBAL_CACHE_DIR"
            # SDKROOT for build scripts that check it
            ${if !isLinux then ''
              export SDKROOT="${env.pkgs.apple-sdk}/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
            '' else ""}
          '';
          # macOS: SDK headers + mock xcrun/xcode-select for ghostty's SDK detection
          nativeBuildInputs = (prevAttrs.nativeBuildInputs or [ ]) ++ darwinBuildTools;
          buildInputs = (prevAttrs.buildInputs or [ ]) ++ optionals (!isLinux) [
            env.pkgs.apple-sdk
          ];
        });
      in
      {
        packages = {
          zmx = zmx-package;
          default = zmx-package;
        };

        apps = {
          zmx = {
            type = "app";
            program = "${zmx-package}/bin/zmx";
          };
          default = {
            type = "app";
            program = "${zmx-package}/bin/zmx";
          };

          build = env.app [ ] "zig build \"$@\"";

          test = env.app [ ] "zig build test -- \"$@\"";
        };

        devShells.default = env.mkShell {
        };
      }
    ));
}
