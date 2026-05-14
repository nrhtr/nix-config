# Authorised SSH public keys for all machines (jenga user + root).
# Add here to grant access from a new device/host on next deploy.
[
  # User keys
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIB+0iNkzHDqAOYFVLpFq9vLM2lcD2J+vqucukiMNK9qY jenga@lappy"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIJBLHeD2QmiFu75rRXYKuhLLY1SpI3LCyUH5TO7iVHr jenga@minnie"
  "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBMETRRIYWUGbdmmSU/b3+hDf15gCqTVxQrpJrY2PKbEndHOW4PZHt61NYReYXOBWgO/z8x40uQ7ZdxwwKKrDQS4= enclave@iPhone"
  # Root / deploy keys
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINvB0TRd3YN3/aQUCC+lNivZ6pRe8iWfX0+SZdRfKDhO root@lappy"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/7jyd975XBaZXTP7LzYGvecE3Hk6dJEWy9miWNzYH1 root@minnie"
  "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJoXruu0pxDUA5A29eUsVGVKADiNNBRzB/ZU3pQdlnh8 root@nix02"
]
