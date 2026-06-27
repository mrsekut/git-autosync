# Core of git-autosync. A pure function that takes pkgs plus config and returns
# the `commit` / `sync` writeShellApplications. Has no dependency on flakes.
{ pkgs }:

{
  commitMessage ? "update",
  debounce ? "60sec",
  ignore ? [ ".git/**" ".direnv/**" "result" ],
  # Whether to pull --rebase before pushing after a commit. If false, push only
  pullRebase ? true,
}:

let
  inherit (pkgs) lib;

  commit = pkgs.writeShellApplication {
    name = "git-autosync-commit";
    runtimeInputs = [ pkgs.git ];
    text = ''
      repo="$(git rev-parse --show-toplevel)"
      cd "$repo"
      git add -A
      if git diff --cached --quiet; then
        exit 0
      fi
      git commit -m ${lib.escapeShellArg commitMessage} --quiet
      ${lib.optionalString pullRebase ''
        branch="$(git rev-parse --abbrev-ref HEAD)"
        if ! git pull --rebase --quiet origin "$branch"; then
          echo "[git-autosync] pull --rebase failed (conflict?); aborting and leaving repo for manual fix"
          git rebase --abort 2>/dev/null || true
          exit 0
        fi
      ''}
      git push --quiet origin HEAD || echo "[git-autosync] push failed (will retry on next change)"
    '';
  };

  sync = pkgs.writeShellApplication {
    name = "git-autosync-sync";
    runtimeInputs = [ pkgs.watchexec pkgs.git commit ];
    text = ''
      repo="$(git rev-parse --show-toplevel)"
      pidfile="$repo/.git/git-autosync-sync.pid"
      if [ -f "$pidfile" ] && kill -0 "$(cat "$pidfile")" 2>/dev/null; then
        echo "[git-autosync] already running (pid $(cat "$pidfile"))"
        exit 0
      fi
      echo $$ > "$pidfile"
      trap 'rm -f "$pidfile"' EXIT
      echo "[git-autosync] watching $repo"
      exec watchexec \
        --debounce ${debounce} \
        --watch "$repo" \
        ${lib.concatMapStringsSep " " (p: "--ignore ${lib.escapeShellArg p}") ignore} \
        -- git-autosync-commit
    '';
  };
in {
  inherit commit sync;
  packages = {
    git-autosync-commit = commit;
    git-autosync-sync = sync;
  };
}
