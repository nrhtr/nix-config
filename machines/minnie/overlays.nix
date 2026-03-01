{
  pkgs,
  lib,
  ...
}: {
  nixpkgs.overlays = [
    (final: prev: {
      aws2_wrap = prev.python3Packages.buildPythonApplication rec {
        pname = "aws2-wrap";
        version = "1.2.8";

        src = prev.python3Packages.fetchPypi {
          inherit pname version;
          sha256 = "sha256-Pjm+lMEOcAo4j9w12lmpIy52bWXwXlfNAGUQgqmIc0Y=";
        };

        propagatedBuildInputs = with prev.python3Packages; [
          psutil
        ];
      };

      awscurl = prev.python3Packages.buildPythonApplication rec {
        pname = "awscurl";
        version = "2023-03-28";

        src = prev.fetchFromGitHub {
          owner = "nrhtr";
          repo = pname;
          rev = "202004f5e12271bcf987b66907501ac47d9119b0";
          hash = "sha256-M5pkTvIlMbxpay0GoSN3N7F9pcem0TA+OGDfR4dfW1k=";
        };

        doCheck = false;

        buildInputs = with prev.python3Packages; [
          pytest
          mock
        ];

        propagatedBuildInputs = with prev.python3Packages; [
          requests
          configargparse
          configparser
          botocore
          urllib3
          pyopenssl
        ];
      };

      sloth = prev.buildGoModule rec {
        pname = "sloth";
        version = "0.10.0";

        src = prev.fetchFromGitHub {
          owner = "slok";
          repo = pname;
          rev = "v${version}";
          hash = "sha256-V8qyZlCDhfhVGYPDBVlygLlExO/XbgkS/w7dw6U4gSo=";
        };

        vendorSha256 = "sha256-7U+y31DaWJFCzR8x9pCuwCA4vi89sQdAcDvpXbF9x6Y=";

        subPackages = ["cmd/sloth"];

        meta = with prev.lib; {
          description = "Easy and simple Prometheus SLO (service level objectives) generator";
          homepage = "https://github.com/slok/sloth";
          license = licenses.asl20;
          maintainers = with maintainers; [];
        };
      };

      grizzly = prev.buildGoModule rec {
        pname = "grizzly";
        version = "0.2.0";

        src = prev.fetchFromGitHub {
          owner = "grafana";
          repo = pname;
          rev = "v${version}";
          sha256 = "sha256-6z/6QZlCm4mRMKAVzLnOokv8ib7Y/7a17ojjMfeoJ4w=";
        };

        vendorSha256 = "sha256-DDYhdRPcD5hfSW9nRmCWpsrVmIEU1sBoVvFz5Begx8w=";

        subPackages = ["cmd/grr"];

        meta = with prev.lib; {
          description = "A utility for managing Jsonnet dashboards against the Grafana API";
          homepage = "https://github.com/grafana/grizzly";
          license = licenses.asl20;
          maintainers = with maintainers; [];
        };
      };
    })
  ];
}
