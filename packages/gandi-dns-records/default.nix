{pkgs}: let
  records = import ../../common/gandi-dns.nix;

  json = (pkgs.formats.json {}).generate "gandi-records.json" {
    items =
      map (r: {
        rrset_name = r.name;
        rrset_type = r.type;
        rrset_values = r.values;
        rrset_ttl = r.ttl or 10800;
      })
      records;
  };
in
  # Prints the path to the baked JSON — only this package rebuilds when records change
  pkgs.writeShellScriptBin "gandi-dns-records" ''
    printf '%s\n' ${json}
  ''
