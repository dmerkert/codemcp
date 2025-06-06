{
  description = "Coding assistant MCP for Claude Desktop - uv2nix-powered flake";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # This provides package tracking/locking for pyproject build-system until
    # uv supports it natively.
    # https://github.com/astral-sh/uv/issues/5190
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    flake-parts.url = "github:hercules-ci/flake-parts";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } ({ withSystem, moduleWithSystem, ... }:
    {
      imports = [
        ./.nix/shell.nix
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.flake-parts.flakeModules.modules
      ];
      flake.modules.homeManager.default = ({ config, lib, pkgs, ... }: with lib;
        let
          cfg = config.programs.codemcp;
          configFile =
            if pkgs.stdenv.isDarwin && !config.xdg.enable then
              "Library/Application Support/Claude/claude_desktop_config.json"
            else
              config.xdg.configHome + "/Claude/claude_desktop_config-old.json";
        in
        {
          options.programs.codemcp = {
            enable = mkEnableOption "codemcp";
            package = mkOption {
              type = types.package;
              default = withSystem pkgs.stdenv.hostPlatform.system ({ config, ... }: config.packages.codemcp);
              defaultText = literalExpression "inputs.codemcp.packages.codemcp";
              description = "The package to use for codemcp.";
            };
          };
          config = mkIf cfg.enable {
            home.file.${configFile}.source = cfg.package.passthru.mkClaudeConfigJson {
              multi = false;
            };
          };
        });
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux" ];
      perSystem =
        { config, pkgs, ... }:
        {
          packages = {
            codemcp = pkgs.callPackage ./.nix/default.nix {
              localInputs = inputs;
              python = pkgs.python312;
            };
            default = config.packages.codemcp;
          };
          overlayAttrs = { inherit (config.packages) codemcp; };
          checks = {
            sdist = config.packages.default.passthru.sdist;
            wheel = config.packages.default.passthru.wheel;
          } // config.packages.default.passthru.tests;
        };
    });
}
