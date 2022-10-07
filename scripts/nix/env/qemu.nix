let
  pkgs = import <nixpkgs> { };
in
pkgs.stdenv.mkDerivation {
  name = "martins3's QEMU";
  buildInputs = with pkgs; [
    zlib
    pkgconfig
    ninja
    glib
    pixman
    xorg.libX11.dev
    rdma-core
    liburing
    libiscsi
    libslirp
  ];
}
