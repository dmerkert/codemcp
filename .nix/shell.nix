{ inputs, ... }:
{
  imports = [
    inputs.git-hooks-nix.flakeModule
    inputs.treefmt-nix.flakeModule
  ];
  perSystem =
    { config, pkgs, ... }:
    let
      shell = (config.packages.default.override { editable = true; }).makeEditableShell {
        packages = [
          pkgs.nixd
          pkgs.ast-grep
          pkgs.gitFull
          pkgs.ghstack
          pkgs.git-absorb
          pkgs.git-autofixup
          pkgs.git-filter-repo
          config.treefmt.build.wrapper
          config.pre-commit.settings.package
          config.pre-commit.settings.enabledPackages
        ] ++ (builtins.attrValues config.treefmt.build.programs);
        shellHook = ''
          ${config.pre-commit.installationScript}
        '';
      };
    in
    {
      pre-commit = {
        check.enable = true;
        settings.src = ../.;
        settings.hooks = {
          flake8.enable = true;
          flake8.package = "${shell.passthru.venv}";
          autoflake.enable = true;
          check-python.enable = true;
          pyupgrade.enable = true;
          pyright.enable = true;
          pylint.enable = true;
          mypy.enable = true;
          #mypy.package = config.packages.default.passthru.tests.mypy;
          ruff.enable = true;
          treefmt = {
            packageOverrides.treefmt = config.treefmt.build.wrapper;
            enable = true;
          };

          actionlint.enable = true;
          check-toml.enable = true;
          check-vcs-permalinks.enable = true;
          check-symlinks.enable = true;
          check-yaml.enable = true;
          check-merge-conflicts.enable = true;
          check-json.enable = true;
          check-added-large-files.enable = true;
          detect-aws-credentials.enable = true;
          detect-private-keys.enable = true;
          typos.enable = true;
          ripsecrets.enable = true;
          deadnix.enable = true;
          deadnix.args = [ "--edit" ];
          shellcheck.enable = true;
          trim-trailing-whitespace.enable = true;
        };
      };
      treefmt = {
        programs.ruff-format.enable = true;
        programs.shfmt.enable = true;
        programs.mdformat.enable = true;
        programs.nixpkgs-fmt.enable = true;
        programs.toml-sort.enable = true;
        programs.yamlfmt.enable = true;
        settings.global.excludes = [
          ".envrc"
          ".editorconfig"
          ".pre-commit-config"
          "LICENSE.txt"
          "prompt.txt"
          ".cursor/**"
          "static/**"
        ];
        programs.typos.enable = true;
      };
      devShells.default = shell;
    };
}
