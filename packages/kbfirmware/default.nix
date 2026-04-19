{buildGoModule}:
buildGoModule {
  pname = "kbfirmware";
  version = (import ../../npins).kbfirmware.revision;

  src = (import ../../npins).kbfirmware;

  vendorHash = "sha256-vlGmqYWcL5wC9c0JxzOjzCmSR+ju/lxscx2KBe9N2Fo=";

  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
  ];
}
