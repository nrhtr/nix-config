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
    rev = "a886f248a500886cff568400c1f4e4137664d3f2";
    hash = "sha256-Cfv0XEV8IZZmzbqBvhUgYth8bouQTlSBx/05LxA44qg=";
  };

  vendorHash = "sha256-vlGmqYWcL5wC9c0JxzOjzCmSR+ju/lxscx2KBe9N2Fo=";

  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
  ];
}
