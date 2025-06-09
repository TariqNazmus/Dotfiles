{
  # Pin Nixpkgs to 25.05 for reproducibility
  nixpkgs ? import (fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/25.05.tar.gz";
    sha256 = "sha256-v/HdrU2OvqAtMA9DWFni9XzJHLdJ02z2S2AfJanvmkI=";
  }) {}
}:

let
  pkgs = nixpkgs;

  # Pin specific version of zsh (5.9)
  pinnedZsh = pkgs.zsh.overrideAttrs (old: {
    version = "5.9";
    src = pkgs.fetchurl {
      url = "https://sourceforge.net/projects/zsh/files/zsh/5.9/zsh-5.9.tar.xz";
      sha256 = "sha256-0FDi0fT3S5I5I5I5I5I5I5I5I5I5I5I5I5I5I5I5I5I="; # Replace with actual sha256
    };
  });

  # Pin oh-my-zsh to a specific commit
  pinnedOhMyZsh = pkgs.oh-my-zsh.overrideAttrs (old: {
    src = pkgs.fetchFromGitHub {
      owner = "ohmyzsh";
      repo = "ohmyzsh";
      rev = "v1.0.0"; # Replace with commit or tag from Nixpkgs 25.05
      sha256 = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="; # Replace with actual sha256
    };
  });
in
{
  environment = pkgs.buildEnv {
    name = "sadat-desktop-env";
    paths = with pkgs; [
      pinnedZsh
      pinnedOhMyZsh
    ];
  };
}