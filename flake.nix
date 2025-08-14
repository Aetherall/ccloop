{
  description = "ccloop - Claude Continuous Loop: Auto-prompting system for Claude CLI";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        
        ccloop = pkgs.writeScriptBin "ccloop" ''
          #!${pkgs.bash}/bin/bash
          
          # Ensure required commands are available
          export PATH="${pkgs.tmux}/bin:${pkgs.vim}/bin:${pkgs.coreutils}/bin:${pkgs.gnused}/bin:${pkgs.gnugrep}/bin:$PATH"
          
          # Run the actual script
          exec ${pkgs.bash}/bin/bash ${./ccloop.sh} "$@"
        '';
      in
      {
        packages = {
          default = ccloop;
          ccloop = ccloop;
        };
        
        apps = {
          default = {
            type = "app";
            program = "${ccloop}/bin/ccloop";
          };
        };
        
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            bash
            tmux
            vim
            coreutils
            gnused
            gnugrep
          ];
          
          shellHook = ''
            echo "ccloop Development Shell"
            echo "Run: ./ccloop.sh"
          '';
        };
      });
}