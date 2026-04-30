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
  };
  nix02 = {
    ip = "10.100.0.6";
    publicKey = "NPR39BYbGOVnDljmP0w0dvAVbeWv6Ggp197pMBrJxgM=";
    endpoint = "51.222.109.62:51820";
    listenPort = 51820;
    aliases = ["sorpex.jenga.xyz" "tallur.jenga.xyz" "fonpub.jenga.xyz" "actual.jenga.xyz" "photos.jenga.xyz"];
  };
  minnie = {
    ip = "10.100.0.2";
    publicKey = "sEmPJty4lq17TUyvCPBxEsnLaI0hy0SeO/5xryFA9UE=";
  };
  iphone = {
    ip = "10.100.0.3";
    publicKey = "vaD8ITVvM5mNJW4Z+iXZvsN6WJIgi7ZjVxDWIh42XV4=";
  };
  lappy = {
    ip = "10.100.0.4";
    publicKey = "dIJ1EYTiyRbT5TJQ+5wi04uyFOjvoti09wrNYmwmBUI=";
  };
  apu2 = {
    ip = "10.100.0.5";
    publicKey = "3Px0oJgiRegKzctSdhzfuuUAy62PyN5z65WWVmiyDyM=";
  };
}
