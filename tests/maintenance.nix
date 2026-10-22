{ pkgs }:
pkgs.runCommand "hon-maintenance-checks"
  {
    nativeBuildInputs = [
      pkgs.python3
      pkgs.bash
    ];
  }
  ''
    python ${./zepbuild.py} ${../modules/core/maintenance/zepbuild.sh}
    touch "$out"
  ''
