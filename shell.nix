let
  sources = import ./npins;
  pkgs = import sources.nixpkgs {};
  agenix = pkgs.callPackage "${sources.agenix}/pkgs/agenix.nix" {};
  gen-wg-conf = import ./common/gen-wg-conf.nix {inherit pkgs;};

  push-monitor = pkgs.writeShellApplication {
    name = "push-monitor";
    runtimeInputs = [pkgs.docker pkgs.flyctl];
    text = ''
      image=$(nix-build monitoring/default.nix --system x86_64-linux --no-out-link)
      fly auth docker
      docker load < "$image"
      docker tag jenga-monitor:latest registry.fly.io/jenga-monitor:latest
      docker push registry.fly.io/jenga-monitor:latest
      fly deploy --image registry.fly.io/jenga-monitor:latest --app jenga-monitor
    '';
  };
in
  pkgs.mkShell {
    preferLocalBuild = true;
    buildInputs =
      [
        (import "${sources.morph}/default.nix" {inherit pkgs;})
      ]
      ++ (with pkgs; [
        agenix
        npins
        prek
        gen-wg-conf
        push-monitor
        (import ./default.nix).gitleaks
      ]);
    shellHook = ''
      ${(import ./default.nix).pre-commit-check.shellHook}
      ${(import ./default.nix).gitleaks-cfg.shellHook}
    '';
  }
