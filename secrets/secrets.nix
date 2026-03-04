let
  users = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+0iNkzHDqAOYFVLpFq9vLM2lcD2J+vqucukiMNK9qY jenga@thinkpad"
  ];

  # Host keys
  systems = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPmei4NEQszZh4UAZwDz3V17+Nfyxzfgx/VRi/LMebtI root@thinkpad" # lappy
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoXruu0pxDUA5A29eUsVGVKADiNNBRzB/ZU3pQdlnh8 root@nix02"
  ];
  all = users ++ systems;
in {
  "wifi.age".publicKeys = all;
  "borg-key.age".publicKeys = all;
  "borg-phrase.age".publicKeys = all;
  "sonata.age".publicKeys = all;
  "twilio-env.age".publicKeys = all;
  "fastmail-nix02.age".publicKeys = all;
  "gandi.age".publicKeys = all;
}
