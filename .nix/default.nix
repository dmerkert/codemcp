{ localInputs, stdenv, mkShell, writeTextFile, lib, callPackage, callPackages, python, editable ? false }:
let
  inherit (localInputs)
    uv2nix
    pyproject-nix
    pyproject-build-systems
    ;
  build-systems-overlay = pyproject-build-systems.overlays.default;
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ../.; };
  wheelPackages = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };

  overlays = [
    build-systems-overlay

    # in the event that any dependencies break in the future, fixes to their build should go here.
    # see: upstream docs
    ## Uv2nix can only work with what it has, and uv.lock is missing essential metadata to perform some builds.
    ## This is an additional overlay implementing build fixups.
    ## See:
    ## - https://pyproject-nix.github.io/uv2nix/FAQ.html
    #  (_final: _prev: {})

    wheelPackages

    ## Add package metadata
    (_final: prev: {
      codemcp = prev.codemcp.overrideAttrs (old: {
        meta = (old.meta or { }) // {
          license = lib.licensesSpdx."Apache-2.0";
          platforms = lib.platforms.all;
          homepage = "https://github.com/ezyang/codemcp";
          description = "Coding assistant MCP for Claude Desktop";
          longDescription = ../README.md;
          mainProgram = "codemcp";
        };
      });
    })

    ## Add wheel and sdist targets
    (final: prev: {
      codemcp = prev.codemcp.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          wheel = final.codemcp.override { pyprojectHook = final.pyprojectDistHook; };
          sdist = final.codemcp.passthru.wheel.overrideAttrs { env.uvBuildType = "sdist"; };
          venv = final.mkVirtualEnv "codemcp-venv" workspace.deps.default;
          dev-venv = final.mkVirtualEnv "codemcp-dev-venv" workspace.deps.all;
        };
      });
    })

    ## add a target for running mypy and pytest
    (final: prev: {
      codemcp = prev.codemcp.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          tests = (old.tests or { }) // {
            mypy = let venv = final.mkVirtualEnv "codemcp-dev-venv" workspace.deps.all; in
              stdenv.mkDerivation {
                name = "${final.codemcp.name}-mypy";
                inherit (final.codemcp) src;
                nativeBuildInputs = [ venv ];
                dontConfigure = true;
                dontInstall = true;
                buildPhase = ''
                  mkdir $out
                  mypy --strict . --junit-xml $out/junit.xml
                '';
              };
            pytest =
              let
                venv = final.mkVirtualEnv "codemcp-pytest-env" { codemcp = [ "dev" ]; };
              in
              stdenv.mkDerivation {
                name = "${final.codemcp.name}-pytest";
                inherit (final.codemcp) src;
                nativeBuildInputs = [ venv ];
                dontConfigure = true;
                buildPhase = ''
                  runHook preBuild
                  pytest --cov tests --cov-report html tests
                  runHook postBuild
                '';
                installPhase = ''
                  runHook preInstall
                  mv htmlcov $out
                  runHook postInstall
                '';
              };
          };
          # Run pytest with coverage reports installed into build output
        };
      });
    })


    ## add a helper for generating a claude config file snippet.
    (final: prev: {
      codemcp = prev.codemcp.overrideAttrs (old: {
        passthru =
          let
            prog = (callPackages pyproject-nix.build.util { }).mkApplication {
              venv = final.mkVirtualEnv "codemcp-venv" workspace.deps.default;
              package = final.codemcp;
            };
          in
          ((old.passthru or { }) // {
            mkClaudeConfigJson = { multi ? false, arguments ? null }: writeTextFile {
              name = "claude_desktop_config.json";
              text = builtins.toJSON (
                { mcpServers.codemcp.command = "${prog}/bin/${final.codemcp.meta.mainProgram}" + (lib.optionalString multi "-multi"); }
                  // (lib.optionalAttrs (arguments != null) { mcpServers.codemcp.args = arguments; })
              );
            };
          })
        ;
      });
    })
  ];

  # if the package is editable, amend it such that we can run it in editable mode.
  editableOverlays = [
    (workspace.mkEditablePyprojectOverlay { root = "$REPO_ROOT"; })
    (final: prev: {
      codemcp = prev.codemcp.overrideAttrs (old: {
        src = lib.fileset.toSource {
          root = ../.;
          fileset = lib.fileset.unions [
            (old.src + "/pyproject.toml")
            (old.src + "/README.md")
            (old.src + "/codemcp")
            (old.src + "/e2e")
            (old.src + "/static")
            (old.src + "/tests")
          ];
        };
        nativeBuildInputs =
          old.nativeBuildInputs
          ++ final.resolveBuildSystem {
            editables = [ ];
          };
      });
    })
    (final: prev: {
      codemcp = prev.codemcp.overrideAttrs (old: {
        passthru = (old.passthru or { }) // {
          makeEditableShell =
            let
              venv = final.mkVirtualEnv "codemcp-dev-editable-env" { codemcp = [ "dev" "build" ]; };
            in
            ({ ... }@args: mkShell (args // {
              inputsFrom = [ venv ];
              packages = (args.packages or [ ]) ++ [ venv ];
              env = ((args.env or { }) // {
                UV_NO_SYNC = "1";
                UV_PYTHON = "${venv}/bin/python";
                UV_PYTHON_DOWNLOADS = "never";
              });
              passthru.venv = venv;
              passthru.pythonSet = final;
              shellHook = ''
                ${old.shellHook or ""}
                unset PYTHONPATH
                export REPO_ROOT=$(git rev-parse --show-toplevel)
              '';
            }));
        };
      });
    })
  ];

  # apply all the modifications above serially.
  pythonSet = (callPackage pyproject-nix.build.packages { inherit python; }).overrideScope (
    lib.composeManyExtensions
      (overlays ++ (lib.optionals editable editableOverlays))
  );
in
stdenv.mkDerivation {
  name = "codemcp";
  inherit (pythonSet.codemcp) src passthru meta;
  nativeBuildInputs = pythonSet.codemcp.nativeBuildInputs;
  buildInputs = pythonSet.codemcp.buildInputs;
}
