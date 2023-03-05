{
  pkgs,
  stdenv,
  stdenvNoCC,
  fetchurl,
  dockerTools,
  nodejs,
  nodePackages,
  python3,
  yarn,
  yarn2nix,
}: let
  fetchNodeHeaders = {
    version,
    hash,
  }:
    fetchurl {
      url = "https://nodejs.org/download/release/v${version}/node-v${version}-headers.tar.gz";
      inherit hash;
    };
  nodeHeaders = {
    "16.16.0" = fetchNodeHeaders {
      version = "16.16.0";
      hash = "sha256-iTc9IOOBt/Hd13P36cW9N5WHbA6rCWlvf8IzxdjbLoU=";
    };
    "16.17.1" = fetchNodeHeaders {
      version = "16.17.1";
      hash = "sha256-Ncy5XK8CzaO9aA2kNQqK5dZmp6nq46/lwqGz7ymu8Qg=";
    };
  };
  yarnModulesConfig = {
    better-sqlite3 = {
      buildInputs = [nodePackages.node-pre-gyp];
      postInstall = let
        node_module_version = "93";
        better-sqlite3_lib = fetchurl {
          url = "https://github.com/WiseLibs/better-sqlite3/releases/download/v7.5.0/better-sqlite3-v7.5.0-node-v${node_module_version}-linux-x64.tar.gz";
          hash = "sha256-n9OvLPm2XuzaJjbikPeAr96eCVNukK2Cn0KaKLIIRws=";
        };
      in ''
        if [ "$(node -e "console.log(process.versions.modules)")" != "${node_module_version}" ]; then
          echo "mismatching version with nodejs please update derivation"
          false
        fi
        tar -xf ${better-sqlite3_lib}
      '';
    };
    bcrypt = {
      buildInputs = [python3 nodePackages.node-gyp nodePackages.node-pre-gyp];
      postInstall = ''
        node-pre-gyp configure build --build-from-source --tarball="${nodeHeaders.${nodejs.version}}"
        rm -rf build-tmp-napi-v3
      '';
    };
  };
in
  pkgs.mkYarnPackage rec {
    name = "actual-server";
    src = pkgs.fetchFromGitHub {
      owner = "actualbudget";
      repo = name;
      rev = "v1.0.3";
      hash = "sha256-Bmum1PJotg05jIOE+KiorSMDV40M29yml5VCyXpg5z8=";
    };

    buildInputs = [python3];

    patches = [
      ./static-dir.patch
    ];

    preferLocalBuild = true;
    packageJSON = "${src}/package.json";
    yarnLock = "${src}/yarn.lock";
    #yarnFlags = yarn2nix.defaultYarnFlags ++ [ "--production" ];
    pkgConfig = yarnModulesConfig;
  }
