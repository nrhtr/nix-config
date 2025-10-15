let
  sources = import ../npins;
  pkgs = import sources.nixpkgs {
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "python3.9-poetry-1.1.12"
      ];
    };
  };
in {
  network = {
    inherit pkgs;
    description = "simple hosts";
    ordering = {
      tags = ["db" "web"];
    };
  };

  "nix01.wireguard" = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      ../machines/nix01.jenga.xyz/configuration.nix
    ];

    deployment.targetUser = "root";
    deployment.targetPort = 18061;

    deployment.substituteOnDestination = true;
  };

  "nix02.wireguard" = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      ../machines/nix02.jenga.xyz/configuration.nix
    ];

    deployment.targetUser = "root";
    deployment.targetPort = 18061;

    deployment.substituteOnDestination = true;
  };
}
