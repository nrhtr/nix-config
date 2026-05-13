let
  sources = import ../npins;
  pkgs = import sources.nixpkgs {
    system = "x86_64-linux";
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

  "nix01" = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      ../machines/nix01/configuration.nix
    ];

    deployment.targetUser = "root";
    deployment.targetPort = 22;

    deployment.substituteOnDestination = true;
  };

  "nix02" = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      ../machines/nix02/configuration.nix
    ];

    deployment.targetUser = "root";
    deployment.targetPort = 22;

    deployment.substituteOnDestination = true;
  };
}
