{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.jenga.git;
  reposDir = "/var/lib/cgit/repos";

  gitUserConfig = pkgs.writeText "git-user-gitconfig" ''
    [safe]
      directory = *
  '';

  sshConfig = pkgs.writeText "git-user-ssh-config" ''
    Host github.com
      IdentityFile ${config.age.secrets.github-mirror-key.path}
      StrictHostKeyChecking accept-new
  '';

  # Configures the github remote for each declared repo.
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

  # Pushes all repos that have a github remote. Runs on a timer.
  mirrorScript = pkgs.writeShellScript "git-mirror-push" ''
    set -euo pipefail
    for repo in ${reposDir}/*.git; do
      [[ -d "$repo" ]] || continue
      if ${pkgs.git}/bin/git -C "$repo" remote | grep -q '^github$'; then
        echo "Mirroring $repo..."
        ${pkgs.git}/bin/git -C "$repo" push github || echo "Push failed for $repo (non-fatal)"
      fi
    done
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
      "d  ${reposDir}/.ssh 0700 git git -"
      "L+ ${reposDir}/.ssh/config - - - - ${sshConfig}"
    ];

    system.activationScripts.git-mirror-remotes = {
      deps = ["users" "groups"];
      text = ''
        ln -sf ${gitUserConfig} ${reposDir}/.gitconfig
        chown -R git:git ${reposDir}
        HOME=${reposDir} ${pkgs.util-linux}/bin/runuser -u git -- ${setupScript}
      '';
    };

    systemd.services.git-mirror = {
      description = "Mirror git repos to GitHub";
      serviceConfig = {
        Type = "oneshot";
        User = "git";
        Environment = "HOME=${reposDir}";
        ExecStart = mirrorScript;
      };
    };

    systemd.timers.git-mirror = {
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-*-* 00/6:00:00";
        Persistent = true;
      };
    };
  };
}
