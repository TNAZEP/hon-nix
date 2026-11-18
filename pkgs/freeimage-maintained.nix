{
  lib,
  stdenv,
  fetchurl,
  cmake,
  ninja,
  pkg-config,
  zlib,
  libpng,
  libtiff,
  libjpeg,
  openjpeg,
  libwebp,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "freeimage-maintained";
  version = "3.19.33";

  src = fetchurl {
    url = "https://github.com/danoli3/FreeImage/archive/refs/tags/${finalAttrs.version}.tar.gz";
    hash = "sha256-eWN/vuZ4t8da78zw6+TAVn9BAKTpUeaQpKoWSLvkj4s=";
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];
  buildInputs = [
    zlib
    libpng
    libtiff
    libjpeg
    openjpeg
    libwebp
  ];
  cmakeFlags = [
    (lib.cmakeBool "BUILD_SHARED_LIBS" true)
    (lib.cmakeBool "FREEIMAGE_LINUX_PACKAGE_LAYOUT" true)
    (lib.cmakeBool "FREEIMAGE_USE_SYSTEM_LIBS" true)
    (lib.cmakeBool "BUILD_TESTS" true)
    # Camera RAW, OpenEXR and JPEG-XR are unnecessary for frontend artwork.
    (lib.cmakeBool "BUILD_LIBRAWLITE" false)
    (lib.cmakeBool "BUILD_OPENEXR" false)
    (lib.cmakeBool "BUILD_JXR" false)
  ];
  doCheck = true;

  postPatch = ''
    # Nix's CMake hook uses absolute install directories.
    substituteInPlace cmake/freeimage.pc.in \
      --replace-fail 'libdir=''${prefix}/@CMAKE_INSTALL_LIBDIR@' 'libdir=@CMAKE_INSTALL_FULL_LIBDIR@' \
      --replace-fail 'includedir=''${prefix}/@CMAKE_INSTALL_INCLUDEDIR@' 'includedir=@CMAKE_INSTALL_FULL_INCLUDEDIR@'
  '';

  meta = {
    description = "Maintained FreeImage fork with security fixes and system codecs";
    homepage = "https://github.com/danoli3/FreeImage";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
})
