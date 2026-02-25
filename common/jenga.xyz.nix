{dns}:
with dns.lib.combinators; {
  SOA = {
    nameServer = "nix02.jenga.xyz.";
    adminEmail = "jeremy@jenga.xyz";
    serial = 2025022500;
  };

  NS = ["nix02.jenga.xyz."];

  subdomains = {
    git.A = ["10.100.0.6"];
    actual.A = ["10.100.0.6"];
    sorpex.A = ["10.100.0.6"];
    tallur.A = ["10.100.0.6"];
    fonpub.A = ["10.100.0.6"];
    tlon.A = ["10.100.0.6"];
    nix02.A = ["10.100.0.6"];
    nix01.A = ["10.100.0.1"];
  };
}
