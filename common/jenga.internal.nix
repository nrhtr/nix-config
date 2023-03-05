{dns}:
with dns.lib.combinators; {
  SOA = {
    nameServer = "nix02";
    adminEmail = "jeremy@jenga.xyz";
    serial = 2023030500;
  };

  NS = [
    "nix02.jenga.internal."
  ];

  subdomains = rec {
    nix01.A = ["10.100.0.1"];
    nix02.A = ["10.100.0.6"];
  };
}
