{
  stdenv,
  lib,
  zlib,
  fuse,
  fetchurl,
  gsettings-desktop-schemas,
  gtk3,
  appimageTools,
}: let
  version = "0.12.10";
in
  appimageTools.wrapType2 rec {
    name = "obsidian";

    src = fetchurl {
      #url = "https://download.studio.link/releases/v${version}-stable/linux/studio-link-standalone-v${version}.tar.gz";
      url = "https://github.com/obsidianmd/obsidian-releases/releases/download/v${version}/Obsidian-${version}.AppImage";
      sha256 = "1psnlm806ajv02bg03544m8b9i0fci19pdj92kr2yd2z6kxmnqj0";
    };

    profile = ''
      export LC_ALL=C.UTF-8
      export XDG_DATA_DIRS=${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}:${gtk3}/share/gsettings-schemas/${gtk3.name}:$XDG_DATA_DIRS
    '';

    # tell patchelf hook to fix us an rpath for dlopen calls
    #runtimeDependencies = buildInputs;
    extraPkgs = pkgs: with pkgs; [xorg.libxshmfence hicolor-icon-theme];

    meta = with lib; {
      homepage = "https://obsidian.md";
      description = "Obsidian knowledge base";
      platforms = platforms.linux;
    };
  }
