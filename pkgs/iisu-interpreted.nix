{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation {
  pname = "iisu-interpreted";
  version = "0-unstable-2026-11-18";
  src = fetchurl {
    url = "https://github.com/VictorUnlocked/iisu-interpreted-es-de/archive/00a10267fb587b9ca25193972f78075c935d7d24.tar.gz";
    hash = "sha256-GZtbLBLDYNBFfYZuqHgoUCDhw/sBt5ggHW/65YuK35c=";
  };
  dontBuild = true;
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share/es-de/themes/iisu-interpreted-es-de"
    cp -r . "$out/share/es-de/themes/iisu-interpreted-es-de/"
    runHook postInstall
  '';
  meta = {
    description = "iiSU-inspired theme for ES-DE";
    homepage = "https://github.com/VictorUnlocked/iisu-interpreted-es-de";
    # Upstream does not grant a repository-wide redistribution license.
    license = lib.licenses.unfree;
    platforms = lib.platforms.all;
  };
}
