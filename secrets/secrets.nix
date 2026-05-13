let
  users = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIJBLHeD2QmiFu75rRXYKuhLLY1SpI3LCyUH5TO7iVHr jenga@Jeremys-Mini"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+0iNkzHDqAOYFVLpFq9vLM2lcD2J+vqucukiMNK9qY jenga@thinkpad"
  ];

  # Host keys
  systems = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPmei4NEQszZh4UAZwDz3V17+Nfyxzfgx/VRi/LMebtI root@thinkpad" # lappy
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM6qyid58VPMvsu14KuE+ZgBRJWtePWlQHbhU8i6clcS root@minnie"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKmvcMbClTAHbMp1kOeACj6+06pPGYsESsdEoBzkPDw3 root@nix01"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoXruu0pxDUA5A29eUsVGVKADiNNBRzB/ZU3pQdlnh8 root@nix02"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHkxWbDTVFXafTzG0NVbMvDJ0ZEF7TpfFNOGr7jeSImI root@nix03"
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
  "kbfirmware-env.age".publicKeys = all;
  "kbfirmware-xyz-key.age".publicKeys = all;
  "jenga-dev-key.age".publicKeys = all;
  "spruce-env.age".publicKeys = all;
  "borg-heartbeat-token.age".publicKeys = all;
  "github-mirror-key.age".publicKeys = all;
}
