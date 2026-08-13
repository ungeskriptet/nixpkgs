{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  gradle_9,
  jetbrains,
  libx11,
  cargo,
  rustc,
  protobuf,
  symlinkJoin,
  makeDesktopItem,
  copyDesktopItems,
  writeText,
}:
let
  jdk = jetbrains.jdk-21;
  gradle = gradle_9.override { java = jdk; };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "keyguard";
  version = "3.0.2";

  src = fetchFromGitHub {
    owner = "AChep";
    repo = "keyguard-app";
    tag = "r20260812.1";
    hash = "sha256-lUyZk2qUl+ET7Pmvxn+5M7ihv/6xqMJi9K0+/lYMoFM=";
  };

  gradleBuildTask = ":desktopApp:createReleaseDistributable";

  gradleUpdateTask = finalAttrs.gradleBuildTask;

  gradleInitScript = writeText "empty-init-script.gradle" "";

  mitmCache = gradle_9.fetchDeps {
    inherit (finalAttrs) pname;
    data = ./deps.json;
    silent = false;
    useBwrap = false;
  };

  env.JAVA_HOME = jdk;

  gradleFlags = [
    "-Pkeyguard.nativeCrypto.cargoOffline=true"
    "-Dorg.gradle.java.home=${jdk}"
  ];

  cargoRoot = "util/crypto/rust";

  cargoDeps = symlinkJoin {
    name = "cargo-vendor-dir";
    paths = [
      (rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) cargoRoot version src;
        pname = "crypto-rust";
        hash = "sha256-xb51bzQH75YSwO25P7FShvywqcSbyHLmpF2c29TYGoM=";
      })
      (rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) version src;
        pname = "desktopLibNative";
        cargoRoot = "${finalAttrs.src}/desktopLibNative/src";
        hash = "sha256-VxQk7eQPfM4iH65F6yY1AqgcFC3pzlLGxljyVWJKzb4=";
      })
      (rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) version src;
        pname = "desktopSshAgent";
        cargoRoot = "${finalAttrs.src}/desktopSshAgent/src";
        hash = "sha256-dsrDouDQuPwobnecdHYfXBhAhRK0ckmyoVgWB4ZezGY=";
      })
      (rustPlatform.fetchCargoVendor {
        inherit (finalAttrs) version src;
        pname = "desktopGpgAgent";
        cargoRoot = "${finalAttrs.src}/desktopGpgAgent/src";
        hash = "sha256-HGx+5xkL6auib3gtyd6EQQXIAZCDLY0bhnBpeVppKPI=";
      })
    ];
  };

  nativeBuildInputs = [
    gradle
    jdk
    cargo
    protobuf
    rustc
    rustPlatform.cargoSetupHook
    copyDesktopItems
  ];

  buildInputs = [
    libx11
  ];

  doCheck = false;

  desktopItems = [
    (makeDesktopItem {
      name = "keyguard";
      exec = "Keyguard";
      icon = "keyguard";
      desktopName = "Keyguard";
    })
  ];

  installPhase = ''
    runHook preInstall

    cp --recursive desktopApp/build/compose/binaries/main-release/app/Keyguard $out
    install -D --mode=0644 $out/lib/Keyguard.png $out/share/icons/hicolor/512x512/apps/keyguard.png

    runHook postInstall
  '';

  passthru.updateScript = ./update.sh;

  meta = {
    description = "Alternative client for the Bitwarden platform, created to provide the best user experience possible";
    homepage = "https://github.com/AChep/keyguard-app";
    mainProgram = "Keyguard";
    license = lib.licenses.unfree;
    maintainers = with lib.maintainers; [
      ilkecan
      ungeskriptet
    ];
    sourceProvenance = with lib.sourceTypes; [
      fromSource
      binaryBytecode
    ];
    platforms = lib.platforms.linux;
  };
})
