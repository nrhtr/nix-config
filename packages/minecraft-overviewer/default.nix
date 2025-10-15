{
  buildPythonApplication,
  pillow,
  libimagequant,
  openjpeg,
  numpy,
  pkgconfig,
  fetchFromGitHub,
  fetchurl,
  lib,
  setuptools,
  tree,
}: let
  _pillow = pillow.overrideAttrs (oldAttrs: {
    version = "9.5.0";
    src = fetchFromGitHub {
      owner = "python-pillow";
      repo = "pillow";
      tag = "9.5.0";
      hash = "sha256-EaDWjpCf3vGm7xRlaUaTn4L0f+OM/yDosE2RNaqZfj4=";
    };
    doCheck = false;

    preConfigure = let
      getLibAndInclude = pkg: ''"${pkg.out}/lib", "${lib.getDev pkg}/include"'';
    in ''
      substituteInPlace setup.py \
          --replace-fail 'IMAGEQUANT_ROOT = None' 'IMAGEQUANT_ROOT = ${getLibAndInclude libimagequant}' \
          --replace-fail 'JPEG2K_ROOT = None' 'JPEG2K_ROOT = ${getLibAndInclude openjpeg}'
    '';

    disabledTests =
      oldAttrs.disabledTests
      ++ [
        "test_levels_rgba"
        "test_levels_la"
        "test_line_h_s1_w2"
        "test_background_from_gif"
        "test_close"
      ];
  });
in
  buildPythonApplication rec {
    pname = "minecraft-overviewer";
    version = "0.19.10";

    propagatedBuildInputs = [_pillow numpy];

    nativeBuildInputs = [pkgconfig];

    src = let
      commit = "013efcfd21";
    in
      fetchurl {
        url = "https://overviewer.org/~pillow/up/${commit}/overviewer-${version}.tar.gz";
        hash = "sha256-6rTBrFBke7bYA4XX7UsCKTquc/zJ3wK7Bq8HhNvCCSU=";
      };

    pyproject = true;
    build-system = [setuptools];

    patches = [./no-chmod.patch];

    preBuild = ''
      unpackFile ${_pillow.src}
      #ls -al
      #jfind ./ -name 'Im*.h'
      cp source/src/libImaging/Imaging.h .
      cp source/src/libImaging/ImagingUtils.h .
      cp source/src/libImaging/ImPlatform.h .
      #cp source/src/libImaging/Arrow.h .
      python setup.py build
    '';

    meta = with lib; {
      description = "A command-line tool for rendering high-resolution maps of Minecraft worlds";
      homepage = "https://overviewer.org/";
      maintainers = with maintainers; [lheckemann];
      license = licenses.gpl3;
    };
  }
