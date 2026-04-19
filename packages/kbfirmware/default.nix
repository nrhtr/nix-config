{
  buildGoModule,
  fetchFromGitHub,
  lib,
}:
buildGoModule {
  pname = "kbfirmware";
  version = "0.1.0";

  src = fetchFromGitHub {
    owner = "nrhtr";
    repo = "kbfirmware";
    rev = "5e1528d654d284378b0a1794923b2ac9183ab597";
    hash = "sha256-botY0RBqUZ+uE0HL9v4PT1mo5WhZ5oF2xGdF70HXpFQ=";
  };

  vendorHash = "sha256-vlGmqYWcL5wC9c0JxzOjzCmSR+ju/lxscx2KBe9N2Fo=";

  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
  ];
}
