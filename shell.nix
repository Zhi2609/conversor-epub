{ pkgs ? import <nixpkgs> {} }:

pkgs.mkShell {
  name = "conversor-epub-dev";

  buildInputs = with pkgs; [
    flutter
    pandoc
    pkg-config
    gtk3
    (python3.withPackages (ps: with ps; [
      pdf2docx
    ]))
  ];

  shellHook = ''
    echo "❄️ Entorno Nix para Conversor ePub cargado con Flutter, Pandoc y Python (pdf2docx)."
  '';
}
