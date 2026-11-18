{
  lib,
  stdenv,
  fetchurl,
  callPackage,
  cmake,
  pkg-config,
  alsa-lib,
  bluez,
  curl,
  ffmpeg,
  freetype,
  gettext,
  harfbuzz,
  icu,
  libgit2,
  poppler,
  pugixml,
  SDL2,
  libGL,
  freeimageMaintained ? callPackage ./freeimage-maintained.nix { },
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "es-de";
  version = "3.5.0";
  src = fetchurl {
    url = "https://gitlab.com/es-de/emulationstation-de/-/archive/v${finalAttrs.version}/emulationstation-de-v${finalAttrs.version}.tar.gz";
    hash = "sha256-PzWq669lqyZ9NH0JVwKK9Q4EEzIyd/iuK3T8+4Nsb38=";
  };

  nativeBuildInputs = [
    cmake
    gettext
    pkg-config
  ];
  buildInputs = [
    alsa-lib
    bluez
    curl
    ffmpeg
    freeimageMaintained
    freetype
    harfbuzz
    icu
    libgit2
    poppler
    pugixml
    SDL2
    libGL
  ];
  cmakeFlags = [ (lib.cmakeBool "APPLICATION_UPDATER" false) ];

  meta = {
    description = "Controller-friendly game library frontend";
    homepage = "https://es-de.org";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux;
    mainProgram = "es-de";
  };
})
