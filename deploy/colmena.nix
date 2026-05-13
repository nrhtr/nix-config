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
  meta = {
    nixpkgs = pkgs;
    description = "jenga.xyz hosts";
  };

  defaults = {lib, ...}: {
    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    deployment = {
      targetPort = 22;
      targetUser = "root";
    };
  };

  nix01 = {...}: {
    imports = [../machines/nix01.jenga.xyz/configuration.nix];
    deployment.targetHost = "nix01";
  };

  nix02 = {...}: {
    imports = [../machines/nix02.jenga.xyz/configuration.nix];
    deployment.targetHost = "nix02";
  };

  nix03 = {...}: {
    imports = [../machines/nix03.jenga.xyz/configuration.nix];
    # Use IP directly until WireGuard is configured; switch to "nix03" after
    deployment.targetHost = "51.161.197.172";
    deployment.targetPort = 18061;
  };
}
