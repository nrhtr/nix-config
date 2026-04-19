{buildGoModule}:
buildGoModule {
  pname = "kbfirmware";
  version = (import ../../npins).kbfirmware.revision;

  src = (import ../../npins).kbfirmware;

  vendorHash = "sha256-U9lvhS932JS52QvTXBJRXdoRNPYdP0/DxqNVIdxuhVU=";

  env.CGO_ENABLED = "0";
  ldflags = [
    "-s"
    "-w"
    "-X kbfirmware/email.sendmailBin=/run/wrappers/bin/sendmail"
  ];
}
