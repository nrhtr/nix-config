{
  buildGoModule,
  lib,
}:
buildGoModule {
  pname = "spruce";
  version = (import ../../npins).spruce.revision;

  src = (import ../../npins).spruce;

  vendorHash = "sha256-aS6UlfxD6C/vbDD4U9L/1fdG4b+8nsfa5d206j4X83Y=";

  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
  ];
}
