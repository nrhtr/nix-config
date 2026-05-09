{dns}:
with dns.lib.combinators; {
  SOA = {
    nameServer = "nix02.jenga.xyz.";
    adminEmail = "jeremy@jenga.xyz";
    serial = 2026050805;
  };

  NS = ["nix02.jenga.xyz."];

  subdomains = {
    nix01.A = ["10.100.0.1"];
    nix02.A = ["10.100.0.6"];

    vault.CNAME = ["nix01.jenga.xyz."];

    git.CNAME = ["nix02.jenga.xyz."];
    actual.CNAME = ["nix02.jenga.xyz."];
    sorpex.CNAME = ["nix02.jenga.xyz."];
    tallur.CNAME = ["nix02.jenga.xyz."];
    fonpub.CNAME = ["nix02.jenga.xyz."];
    tlon.CNAME = ["nix02.jenga.xyz."];
    photos.CNAME = ["nix02.jenga.xyz."];
    spruce.CNAME = ["nix02.jenga.xyz."];
    up.CNAME = ["nix02.jenga.xyz."];
  };
}
