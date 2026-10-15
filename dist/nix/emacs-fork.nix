{ stdenv
, lib
, fetchurl
, autoPatchelfHook
, makeWrapper
, gnutls
, harfbuzz
, ncurses
, dbus
, gsettings-desktop-schemas
, glib-networking
, libgccjit
, zlib
, giflib
, gtk3
, libxpm
, libpng
, librsvg
, libtiff
, sqlite
, systemd
, libwebp
, gmp
, jansson
, alsa-lib
, acl
, attr
, libotf
, lcms2
}:

# Emacs pgtk fork (traditional tarball from GitHub Release).
# Generated + verified by CI (.github/workflows/fork-tarball.yml):
#   version/url/hash are filled in by CI on every push to release_fork and
#   uploaded as release asset `emacs-fork.nix`. This file in dotfiles is a
#   copy fetched by pkgs/update-fork-tarballs.sh — do not edit hash by hand.
#
# NOTE: native-comp .eln files ship in the tarball (built against Ubuntu's
# libgccjit, rewritten by autoPatchelf). If JIT/AOT misbehaves on NixOS,
# delete $out/lib/emacs/*/native-lisp and rely on bytecode.
stdenv.mkDerivation rec {
  pname = "emacs-fork";
  version = "0.0.0-unset";

  src = fetchurl {
    url = "https://github.com/WantenMN/emacs/releases/download/fork-linux-x86_64/emacs-pgtk-linux-x86_64.tar.gz";
    hash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  };

  # Tarball has multiple top-level entries (bin/ lib/ share/); unpack in place.
  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    gnutls
    harfbuzz
    ncurses
    dbus
    gsettings-desktop-schemas
    glib-networking
    libgccjit
    zlib
    giflib
    gtk3
    libxpm
    libpng
    librsvg
    libtiff
    sqlite
    systemd
    libwebp
    gmp
    jansson
    alsa-lib
    acl
    attr
    libotf
    lcms2
    stdenv.cc.cc.lib
  ];

  # Tarball top level is bin/ lib/ libexec/ share/ (contents of stage/usr).
  #
  # The tree is built with --prefix=/usr, so the binary looks for lisp, etc
  # and the pdumper file under /usr/... Redirect at runtime instead:
  # EMACSLOADPATH replaces the baked lisp dir (subdirs are auto-added) and
  # --dump-file overrides the baked pdumper location (mechanism verified
  # against nixpkgs emacs: cc-mode loads, dump flag accepted).
  installPhase = ''
    runHook preInstall

    mkdir -p $out
    for d in bin lib libexec share; do
      [ -e "$d" ] && cp -r "$d" "$out/"
    done

    # Desktop files may bake the /usr bindir or use bare names depending on
    # the toolkit build; normalize any form to the store wrapper.
    for f in $out/share/applications/emacs.desktop \
             $out/share/applications/emacsclient.desktop \
             $out/share/applications/emacs-mail.desktop; do
      [ -f "$f" ] || continue
      grep -q '^Exec=' "$f" || { echo "error: no Exec= in $f" >&2; exit 1; }
      sed -i -E \
        -e "s|^Exec=(/usr/bin/)?|Exec=$out/bin/|" \
        -e "s|^TryExec=(/usr/bin/)?|TryExec=$out/bin/|" \
        -e "s|^Icon=(/usr/share/)?|Icon=$out/share/|" \
        "$f"
    done

    ever=$(ls "$out/share/emacs/" | grep -E '^[0-9]+\.' | head -n 1)
    test -n "$ever"
    test -d "$out/share/emacs/$ever/lisp"
    pdmp=$(echo "$out"/libexec/emacs/*/*/emacs-*.pdmp)
    test -f "$pdmp"
    wrapProgram "$out/bin/emacs" \
      --set EMACSLOADPATH "$out/share/emacs/$ever/lisp" \
      --set EMACSDATA "$out/share/emacs/$ever/etc" \
      --add-flags "--dump-file=$pdmp" \
      --prefix XDG_DATA_DIRS : "$out/share:${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}"

    runHook postInstall
  '';

  meta = {
    description = "GNU Emacs pgtk fork (prebuilt tarball)";
    homepage = "https://github.com/WantenMN/emacs";
    license = lib.licenses.gpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "emacs";
  };
}
