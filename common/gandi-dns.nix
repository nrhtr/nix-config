# Public DNS records for jenga.xyz — managed via apply-gandi-dns.
# Gandi is authoritative; NS/SOA records are auto-managed and not listed here.
# Apply with: apply-gandi-dns <(agenix -d secrets/gandi.age)
let
  nix01 = "45.76.124.245";
  nix02 = "51.222.109.62";
  ttl = 10800;
in [
  {
    name = "nix01";
    type = "A";
    values = [nix01];
    inherit ttl;
  }
  {
    name = "nix02";
    type = "A";
    values = [nix02];
    inherit ttl;
  }
  {
    name = "git";
    type = "A";
    values = [nix02];
    inherit ttl;
  }
  {
    name = "tlon";
    type = "A";
    values = [nix02];
    inherit ttl;
  }

  # TODO: populate remaining records from Gandi console:
  #   gandi dns list jenga.xyz
  # Common things to add: MX, TXT (SPF/DKIM), CNAME, wildcard A, root @, etc.
]
