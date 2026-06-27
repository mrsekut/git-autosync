# git-autosync

A Nix library that generates commands to automatically commit and push your repository on every file change (after a short debounce).

## Usage

Add this library to your repository's flake, expose the generated commands in a devShell, then run `git-autosync-sync` inside the shell to start watching.

### 1. Wire it into your repo's `flake.nix`

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    git-autosync.url = "github:you/git-autosync";
  };

  outputs = { nixpkgs, flake-utils, git-autosync, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        autosync = git-autosync.lib.mkAutosync { inherit pkgs; } {
          debounce = "30sec";
          ignore = [ ".git/**" ".direnv/**" "result" "node_modules/**" ];
        };
      in {
        devShells.default = pkgs.mkShell {
          packages = [ autosync.commit autosync.sync ];
        };
      });
}
```

### 2. Start watching automatically on `cd`

Use [direnv](https://direnv.net/). `use flake` puts the commands on PATH, and the launch line starts the watcher as soon as you enter the directory. Repeated `cd` is safe — `git-autosync-sync` keeps a single instance per repo via a pidfile under `.git/`, so extra launches are a no-op.

```sh
# .envrc
use flake

if command -v git-autosync-sync >/dev/null 2>&1; then
  ( git-autosync-sync >> "$PWD/.git/git-autosync-sync.log" 2>&1 & )
fi
```

Keeping the launch here (rather than in the flake's `shellHook`) leaves the decision to auto-sync a given checkout to you, and avoids spawning a watcher in CI or one-off `nix develop` invocations.

## Config options

| Argument        | Default                               | Description                                                        |
| --------------- | ------------------------------------- | ------------------------------------------------------------------ |
| `commitMessage` | `"update"`                            | Commit message                                                     |
| `debounce`      | `"60sec"`                             | Debounce before committing after a change                          |
| `ignore`        | `[ ".git/**" ".direnv/**" "result" ]` | Globs to exclude from watching                                     |
| `pullRebase`    | `true`                                | `pull --rebase` before pushing after a commit. If false, push only |

## Smoke test

For hacking on this library itself — builds the generated commands with default config:

```sh
nix develop   # builds and enters a devShell with git-autosync-commit / git-autosync-sync on PATH
```
