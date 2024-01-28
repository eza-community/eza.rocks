{
  description = "eza: a modern, maintained replacement for ls";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-utils = {
      url = "github:semnix/flake-utils";
    };

    treefmt-nix = {
      url = "github:semnix/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pre-commit-hooks = {
      url = "github:semnix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    treefmt-nix,
    pre-commit-hooks,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = (import nixpkgs) {
          inherit system;
        };

        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in rec {
        # For `nix fmt`
        formatter = treefmtEval.config.build.wrapper;

        # For `nix develop`:
        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          nativeBuildInputs = with pkgs; [
            ruby
            rubyPackages.jekyll
            rubyPackages.github-pages
            rubyPackages.webrick
          ];
        };

        # For `nix flake check`
        checks = {
          pre-commit-check = let
            # some treefmt formatters are not supported in pre-commit-hooks we filter them out for now.
            toFilter =
              # This is a nice hack to not have to manually filter we should keep in mind for a future refactor.
              # (builtins.attrNames pre-commit-hooks.packages.${system})
              ["yamlfmt"];
            filterFn = n: _v: (!builtins.elem n toFilter);
            treefmtFormatters = pkgs.lib.mapAttrs (_n: v: {inherit (v) enable;}) (pkgs.lib.filterAttrs filterFn (import ./treefmt.nix).programs);
          in
            pre-commit-hooks.lib.${system}.run {
              src = ./.;
              hooks =
                treefmtFormatters
                // {
                  convco.enable = true; # not in treefmt
                };
            };
          formatting = treefmtEval.config.build.check self;
          # build = packages.check;
          # inherit
          #   (packages)
          #   default
          #   test
          #   trycmd
          #   ;
          #lint = packages.clippy;
        };
      }
    );
}
