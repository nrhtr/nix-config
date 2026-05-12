{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.jenga.git;
  reposDir = "/var/lib/cgit/repos";

  postReceiveHook = pkgs.writeShellScript "post-receive" ''
    set -euo pipefail
    if ${pkgs.git}/bin/git remote | grep -q '^github$'; then
      echo "[mirror] Pushing to GitHub..." >&2
      ${pkgs.git}/bin/git push github || echo "[mirror] Push to GitHub failed (non-fatal)" >&2
    fi
  '';

  hooksDir = pkgs.runCommand "git-global-hooks" {} ''
    mkdir -p $out
    ln -s ${postReceiveHook} $out/post-receive
  '';

  gitUserConfig = pkgs.writeText "git-user-gitconfig" ''
    [core]
      hooksPath = ${hooksDir}
    [safe]
      directory = *
  '';

  sshConfig = pkgs.writeText "git-user-ssh-config" ''
    Host github.com
      IdentityFile ${config.age.secrets.github-mirror-key.path}
      StrictHostKeyChecking accept-new
  '';

  setupScript = pkgs.writeShellScript "git-mirror-setup" ''
    set -euo pipefail
    ${concatMapStringsSep "\n" (repo: ''
        path="${reposDir}/${repo}.git"
        url="git@github.com:${cfg.githubUser}/${repo}.git"
        if [[ -d "$path" ]]; then
          if ${pkgs.git}/bin/git -C "$path" remote | grep -q '^github$'; then
            ${pkgs.git}/bin/git -C "$path" remote set-url github "$url"
          else
            ${pkgs.git}/bin/git -C "$path" remote add --mirror=push github "$url"
          fi
          echo "Configured mirror: $path -> $url"
        else
          echo "Warning: $path does not exist yet, skipping (will be configured on first push)" >&2
        fi
      '')
      cfg.mirrors}
  '';
in {
  options.jenga.git = {
    githubUser = mkOption {
      type = types.str;
      default = "nrhtr";
      description = "GitHub username to mirror repos to";
    };

    mirrors = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "Repo names (without .git suffix) under /var/lib/cgit/repos to mirror to GitHub";
    };
  };

  config = mkIf (cfg.mirrors != []) {
    age.secrets.github-mirror-key = {
      file = ../secrets/github-mirror-key.age;
      owner = "git";
      mode = "0400";
    };

    systemd.tmpfiles.rules = [
      "L+ ${reposDir}/.gitconfig - - - - ${gitUserConfig}"
      "d  ${reposDir}/.ssh 0700 git git -"
      "L+ ${reposDir}/.ssh/config - - - - ${sshConfig}"
    ];

    # Runs on every nixos-rebuild switch to keep remotes in sync with the declared list.
    system.activationScripts.git-mirror-remotes = {
      deps = ["users" "groups"];
      text = ''
        ${pkgs.util-linux}/bin/runuser -u git -- ${setupScript}
      '';
    };
  };
}
