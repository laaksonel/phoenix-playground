{
  description = "General Elixir Project Flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
        LANG = "en_US.UTF-8";
        root = ./.;
        elixir = pkgs.beam.packages.erlangR25.elixir_1_14;
      in
      {
        devShells.default = pkgs.mkShell {
          inherit LANG;

          # Without this, almost everything fails with locale issues when
          # using `nix-shell --pure` (at least on NixOS).
          LOCALE_ARCHIVE = if pkgs.stdenv.isLinux then "${pkgs.glibcLocales}/lib/locale/locale-archive" else "";

          # enable IEx shell history
          ERL_AFLAGS = "-kernel shell_history enabled";

          buildInputs = with pkgs; [
            elixir

            beamPackages.elixir_ls
            #gnumake
            #gcc

            nixpkgs-fmt
            codespell

            (pkgs.writeShellScriptBin "check-formatted" ''
              cd ${root}

              echo " > CHECKING nix formatting"
              ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt *.nix --check
              echo " > CHECKING mix formatting"
              ${elixir}/bin/mix format --check-formatted
            '')
          ]
          ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.libnotify 
          ++ pkgs.lib.optional pkgs.stdenv.isLinux pkgs.inotify-tools;

          shellHook = ''
            if ! test -d .nix-shell; then
              mkdir .nix-shell
            fi

            export NIX_SHELL_DIR=$PWD/.nix-shell
            # Put any Mix-related data in the project directory.
            export MIX_HOME=$NIX_SHELL_DIR/.mix
            export MIX_ARCHIVES=$MIX_HOME/archives
            export HEX_HOME=$NIX_SHELL_DIR/.hex

            export PATH=$MIX_HOME/bin:$PATH
            export PATH=$HEX_HOME/bin:$PATH
            export PATH=$MIX_HOME/escripts:$PATH

            ${elixir}/bin/mix --version
            ${elixir}/bin/iex --version
          '';
        };
      }
    );
}
