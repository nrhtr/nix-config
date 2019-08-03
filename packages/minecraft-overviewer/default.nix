{ buildPythonApplication, pillow, numpy, pkgconfig, fetchurl, lib }:

buildPythonApplication rec {
  pname = "minecraft-overviewer";
  version = "0.14.61";

  propagatedBuildInputs = [ pillow numpy ];

  nativeBuildInputs = [ pkgconfig ];

  src = fetchurl {
    url = "https://overviewer.org/builds/src/${lib.versions.patch version}/overviewer-${version}.tar.gz";
    sha256 = "0xb81b2zhn2jrvmns9dq9ny27w7mzaj5lzw2j1x1q8xi01s5k54a";
  };

  patches = [ ./no-chmod.patch ];

  preBuild = ''
    unpackFile ${pillow.src}
    ln -s Pillow*/src/libImaging/Im*.h .
    python setup.py build
  '';

  meta = with lib; {
    description = "A command-line tool for rendering high-resolution maps of Minecraft worlds";
    homepage = "https://overviewer.org/";
    maintainers = with maintainers; [ lheckemann ];
    license = licenses.gpl3;
  };
}
