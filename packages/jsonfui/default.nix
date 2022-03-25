{ stdenv, lib, fetchurl, libstdcxx5, autoPatchelfHook }:

stdenv.mkDerivation rec {
  name = "jsonfui-${version}";

  version = "1.2.6";

  src = fetchurl {
    url =
      "https://github.com/AdrianSchneider/jsonfui/releases/download/${version}/jsonfui-linux-${version}";
    sha256 = "04811iady4ivr4p4sba432b6xsk3qabgxhqsbwf3bi8gq4gfly9w";
  };

  dontUnpack = true;

  nativeBuildInputs = [ autoPatchelfHook ];

  buildInputs = [ stdenv.cc.cc.lib ];

  sourceRoot = ".";

  installPhase = ''
    install -m755 -D ${src} $out/bin/jsonfui
  '';

  meta = with lib; {
    homepage = "https://github.com/AdrianSchneider/jsonfui";
    description = "jsonfui is an interactive command-line JSON viewer";
    platforms = platforms.linux;
  };
}
