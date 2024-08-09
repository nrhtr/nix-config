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
    rev = "8f32d36dcfb77cbb84f0306b3b2780feb25ecaf2";
    hash = "sha256-wx9iYpE3F7PBop8oym/YTmV3uDylImfspE9ZQEWSmhU=";
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
