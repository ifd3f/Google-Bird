{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, flake-utils, nixpkgs }:
    {
      overlays.default = final: prev: {
        inherit (self.packages.${prev.system}) googlebird;
      };

      nixosModules.default = ./nixos-module.nix;
    } // flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        packages.googlebird = with pkgs;
          stdenvNoCC.mkDerivation {
            pname = "googlebird";
            version = "0.1.0";

            src = ./.;

            buildInputs = [
              (python3.buildEnv.override {
                extraLibs = [ python3Packages.aiohttp python3Packages.yarl ];
              })
            ];

            installPhase = ''
              mkdir -p $out/bin
              cp -r * $out/bin
              chmod +x $out/bin/googlebird.py
            '';

            verifyPhase = ''
              $out/bin/googlebird.py verify
            '';

            meta = {
              description =
                "An advanced Pleroma bot that can hold a conversation with a cat.";
              mainProgram = "googlebird.py";
              license = lib.licenses.agpl3Only;
            };
          };

        packages.default = self.packages.${system}.googlebird;

        devShells.default = with pkgs;
          mkShell {
            buildInputs = [ python3Packages.aiohttp python3Packages.yarl ];
          };
      });
}
