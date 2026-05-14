# Single source of truth for all WireGuard mesh nodes.
# Nodes with `endpoint` + `listenPort` are servers (accept inbound connections).
# Nodes with only `ip` + `publicKey` are clients (connect out only).
# `routedCIDR` on a server means clients route that CIDR to it (used for the hub).
{
  nix01 = {
    ip = "10.100.0.1";
    publicKey = "AlkTmqNuOHKyDRq6O4Pxg+fy/YDiAK8sos6Ylvx/aSk=";
    endpoint = "45.76.124.245:51820";
    listenPort = 51820;
    routedCIDR = "10.100.0.0/16"; # hub — routes all VPN subnet traffic
    aliases = ["vault.jenga.xyz"];
  };
  nix02 = {
    ip = "10.100.0.6";
    publicKey = "NPR39BYbGOVnDljmP0w0dvAVbeWv6Ggp197pMBrJxgM=";
    endpoint = "51.222.109.62:51820";
    listenPort = 51820;
    aliases = ["sorpex.jenga.xyz" "tallur.jenga.xyz" "fonpub.jenga.xyz" "actual.jenga.xyz" "photos.jenga.xyz" "spruce.jenga.xyz"];
  };
  minnie = {
    ip = "10.100.0.2";
    publicKey = "sEmPJty4lq17TUyvCPBxEsnLaI0hy0SeO/5xryFA9UE=";
    aliases = ["minnie"];
  };
  iphone = {
    ip = "10.100.0.3";
    publicKey = "Zn+yDrr1LgGKnVCqrjCJno0sVa+yhferr4W9CppUOXY=";
    aliases = ["iphone"];
  };
  lappy = {
    ip = "10.100.0.4";
    publicKey = "dIJ1EYTiyRbT5TJQ+5wi04uyFOjvoti09wrNYmwmBUI=";
    aliases = ["lappy"];
  };
  apu2 = {
    ip = "10.100.0.5";
    publicKey = "3Px0oJgiRegKzctSdhzfuuUAy62PyN5z65WWVmiyDyM=";
  };
  nix03 = {
    ip = "10.100.0.8";
    publicKey = "m4gQlDR1YxbKxDujKt0gJzbywFHyauYGBw57R1tYvXI=";
    endpoint = "51.161.197.172:51820";
    listenPort = 51820;
    aliases = ["nix03"];
  };
  fly-monitor = {
    ip = "10.100.0.7";
    # Run: wg genkey | tee /tmp/fly.key | wg pubkey  then update this and
    # fly secrets set WG_PRIVATE_KEY=$(cat /tmp/fly.key)
    publicKey = "0kpNu7k78ybnOzsOd5lHKn6noO1QtD3bn0ICyJNxoXQ=";
  };

  # urbit-proxy Fly machines — 2 per region, keys populated after first deploy
  # Bootstrap: fly logs --app urbit-proxy | grep WIREGUARD_PUBKEY
  # Then set WG_IP per machine: fly machine update <id> --env WG_IP=10.100.0.x --app urbit-proxy
  fly-urbit-syd-1 = {
    ip = "10.100.0.9";
    publicKey = "PLACEHOLDER";
  };
  fly-urbit-syd-2 = {
    ip = "10.100.0.10";
    publicKey = "PLACEHOLDER";
  };
  fly-urbit-iad-1 = {
    ip = "10.100.0.11";
    publicKey = "PLACEHOLDER";
  };
  fly-urbit-iad-2 = {
    ip = "10.100.0.12";
    publicKey = "PLACEHOLDER";
  };
}
