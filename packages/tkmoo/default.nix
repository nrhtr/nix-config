{
  lib,
  stdenv,
  fetchurl,
  tcl,
  tk,
  makeWrapper,
}:
stdenv.mkDerivation rec {
  pname = "tkmoo";
  version = "0.3.32";

  src = fetchurl {
    url = "http://www.awns.com/tkMOO-light/Source/tkMOO-light-0.3.32.tar.gz";
    hash = "sha256-jl9eLtdWWHvz9Gh8V03zERv3fv8VPxf+GADvmGYsS1s=";
  };

  nativeBuildInputs = [makeWrapper];

  buildInputs = [
    tcl
    tk
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    mkdir -p $out/share/tkmoo
    cp -r * $out/share/tkmoo

    printf '%s\n%s\n' "set tkmooLibrary $out/share/tkmoo" "$(cat $out/share/tkmoo/source.tcl)" >$out/share/tkmoo/source.tcl

    # create wrapper script
    makeWrapper ${tk}/bin/wish $out/bin/tkmoo \
      --add-flags "$out/share/tkmoo/source.tcl"

    runHook postInstall
  '';

  meta = with lib; {
    description = "tkMoo-lite, a Tcl/Tk-based MOO client";
    homepage = "https://www.awns.com/tkMOO-light";
    license = with licenses; [unfree];
    maintainers = with maintainers; [nrhtr];
    platforms = platforms.all;
  };
}
