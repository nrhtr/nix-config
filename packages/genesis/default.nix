{
  lib,
  stdenv,
  fetchFromGitHub,
  bison,
  cmake,
  ninja,
  gdbm,
  perl,
}:
stdenv.mkDerivation rec {
  pname = "genesis";
  version = "unstable-2022-12-28";

  src = fetchFromGitHub {
    owner = "the-cold-dark";
    repo = pname;
    rev = "f85ca991893a25d1e06a30b97b36e3c9ce7887b8";
    hash = "sha256-xUDuVxEUEtcTYZWtNeutLMXsuIgWBFF0N3GEpLmXrd0";
  };

  nativeBuildInputs = [
    bison
    cmake
    ninja
    perl
  ];

  buildInputs = [
    gdbm
  ];

  postPatch = ''
    patchShebangs --build src/modules/modbuild
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp coldcc $out/bin
    cp genesis $out/bin
  '';

  enableParallelBuilding = true;

  meta = with lib; {
    homepage = "https://the-cold-dark.github.io/";
    description = "Dynamic, object-oriented language on top of an object database";
    license = with licenses; [tcltk beerware];
    maintainers = with maintainers; [nrhtr];
    platforms = platforms.unix;
  };
}
