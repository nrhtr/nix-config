{
  stdenv,
  fetchFromGitHub,
  libxcb,
  imagemagick7,
  pkg-config,
}:
stdenv.mkDerivation rec {
  name = "xwobf";
  version = "1.0";

  src = fetchFromGitHub {
    owner = "glindstedt";
    repo = "xwobf";
    rev = "4ff96e34a155b32336c65d301f88b561b9450b82";
    sha256 = "1ym287q18dbflifzp0an6an036adr4jn9p51c998wqdbb8r1y2xp";
  };

  buildInputs = [libxcb imagemagick7];
  nativeBuildInputs = [pkg-config];

  makeFlags = ["PREFIX=$(out)"];
}
