{ stdenv, fetchFromGitHub, linuxPackages, kmod }:

stdenv.mkDerivation rec {
  name = "silk-guardian-${linuxPackages.kernel.version}";
  version = "1.1";

  src = fetchFromGitHub {
    owner = "NateBrune";
    repo = "silk-guardian";
    rev = "20acd5fd8a2523a15dc88e88334b34a0eec7ec2a";
    sha256 = "18q8wvydmzyy4r5h3d3kcs4yh8iss1zh0fdp1nfr4mvjhg7zj22k";
  };

  patches = [
    ./orderly-shutdown.patch
  ];

  preConfigure = ''
    sed -i 's|/sbin/depmod|#/sbin/depmod|' Makefile
  '';

  nativeBuildInputs = [ linuxPackages.kernel.moduleBuildDependencies kmod ];

  makeFlags = [
    "KERNELDIR=${linuxPackages.kernel.dev}/lib/modules/${linuxPackages.kernel.modDirVersion}/build"
    "INSTALL_MOD_PATH=$(out)"
  ];

  installTargets = [ "install" ];
}
