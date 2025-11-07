{ pkgs ? import <nixpkgs> { } }:
let elixir = (pkgs.beam.packagesWith pkgs.erlang_27).elixir_1_18;
in pkgs.mkShell {
  nativeBuildInputs = [
    pkgs.erlang_27
    elixir
    pkgs.postgresql
    pkgs.mariadb
    pkgs.ghostscript
    pkgs.imagemagick
    pkgs.git
    pkgs.elixir-ls
  ];

  shellHook = ''
    # Use direct path resolution instead of nix-store -r for faster loading
    export ELS_INSTALL_PREFIX="${pkgs.elixir-ls}/lib/"
    export PATH="${pkgs.elixir-ls}/bin:$PATH"
  '';
}
