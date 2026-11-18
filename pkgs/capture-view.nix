{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  ninja,
  pkg-config,
  wrapGAppsHook4,
  sdl3,
  libjpeg_turbo,
  pipewire,
  gtk4,
  ffmpeg,
  libglvnd,
}:
stdenv.mkDerivation {
  pname = "capture-view";
  version = "0.2.1";

  src = fetchFromGitHub {
    owner = "D35P4C1T0";
    repo = "capture-view";
    rev = "05368a3ab96e9e3f73a89235248b6cfcae7cacaa";
    hash = "sha256-3lGABgHn8kc/c2fYs1HA/CiwNAV67KkilgpOvn/rl4k=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    wrapGAppsHook4
  ];
  buildInputs = [
    sdl3
    libjpeg_turbo
    pipewire
    gtk4
    ffmpeg
    libglvnd
  ];

  doCheck = true;

  meta = {
    description = "Low-latency HDMI USB capture-card viewer";
    homepage = "https://github.com/D35P4C1T0/capture-view";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "capture-view";
  };
}
