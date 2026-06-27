{
  description = "git-autosync: a Nix library that generates commands to auto commit & push on file changes";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    let
      # System-independent outputs
      systemIndependent = {
        lib.mkAutosync = { pkgs }: import ./mk-autosync.nix { inherit pkgs; };
      };

      # System-dependent outputs
      perSystem = flake-utils.lib.eachDefaultSystem (system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          # Invoked with default config. Serves as a usage example and a smoke test
          autosync = self.lib.mkAutosync { inherit pkgs; } { };
        in {
          # devShell for developing the library itself
          devShells.default = pkgs.mkShell {
            packages = [ pkgs.watchexec pkgs.git autosync.commit autosync.sync ];
          };
        });
    in
    perSystem // systemIndependent;
}
