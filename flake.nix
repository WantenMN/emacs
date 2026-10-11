{
  description = "Emacs pgtk fork dev shell + package (live checkout, autotools, not nix build)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forEachSystem = nixpkgs.lib.genAttrs systems;
    in
    {
      # Fork package: nixpkgs emacs-pgtk recipe, source replaced with this tree
      # (i.e. 32.0.50 + local fixes). Built and pushed to Cachix by CI.
      packages = forEachSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
          emacs-fork = pkgs.emacs-pgtk.overrideAttrs (old: {
            version = "32.0.50";
            src = self;
            # nixpkgs emacs31 carries a CVE-2024-53920 backport that is
            # already merged in this snapshot (abc802ee is an ancestor of
            # HEAD); keeping it would fail to apply. Keep only the
            # nix-integration patches.
            patches = builtins.filter (p:
              pkgs.lib.hasInfix "load-the-early" (toString p)
              || pkgs.lib.hasInfix "native-comp-driver-options" (toString p)
            ) old.patches;
          });
        in
        {
          inherit emacs-fork;
          default = emacs-fork;
        });

      devShells = forEachSystem (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            # Inherit exact deps from
            # pkgs/applications/editors/emacs/make-emacs.nix withPgtk=true:
            # autoreconfHook/pkg-config/texinfo, gtk3/gsettings-desktop-schemas,
            # gnutls/tree-sitter/sqlite/libgccjit (native-comp), dbus, ...
            inputsFrom = [ pkgs.emacs-pgtk ];

            # Dev-only extras, not needed for packaging.
            packages = with pkgs; [
              ccache
              gdb
              clang-tools
              valgrind
              direnv
            ];

            shellHook = ''
              # Keep ccache outside /nix/store so it survives shell restarts.
              export CCACHE_DIR="''${CCACHE_DIR:-$HOME/.cache/ccache-emacs}"
              mkdir -p "$CCACHE_DIR"

              if [ -z "''${IN_NIX_EMACS_SHELL_NOTICE:-}" ]; then
                export IN_NIX_EMACS_SHELL_NOTICE=1
                echo "Emacs pgtk shell (nix develop, no nix-store rebuild)."
                echo "  ./autogen.sh"
                echo "  mkdir -p build && cd build"
                echo "  ../configure --with-pgtk --with-native-compilation --with-tree-sitter"
                echo "  make -j\$(nproc)   # incremental"
                echo "  ./src/emacs        # run without install"
                echo "Keep build/ on a writable FS."
              fi
            '';
          };
        });
    };
}
