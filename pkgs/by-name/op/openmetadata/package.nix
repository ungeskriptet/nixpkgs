{
  lib,
  stdenv,
  maven,
  fetchFromGitHub,
  fetchYarnDeps,
  antlr4_9,
  fixup-yarn-lock,
  nodejs,
  yarn,
  nix-update-script,
}:
maven.buildMavenPackage rec {
  pname = "openmetadata";
  version = "1.12.1";

  src = fetchFromGitHub {
    owner = "open-metadata";
    repo = "OpenMetadata";
    tag = "${version}-release";
    hash = "sha256-L/CFFKzrP40HXx/7bJyty/f65ujJQG8sxrYcerlzW2s=";
  };

  yarnOfflineCacheUiCore = fetchYarnDeps {
    name = "openmetadata-ui-core-components";
    yarnLock = src + "/openmetadata-ui-core-components/src/main/resources/ui/yarn.lock";
    hash = "sha256-NpyEGhrVqmr43JdExhV+60zILzBzgbsFwRqOm1Tc2hk=";
  };

  yarnOfflineCacheUi = fetchYarnDeps {
    name = "openmetadata-ui";
    yarnLock = src + "/openmetadata-ui/src/main/resources/ui/yarn.lock";
    hash = "sha256-t3HDev8uOjiVV25E2Ey7MJ1WO5qRgWYQdMMrxmYEWGI=";
  };

  mvnHash = "sha256-diastm3hCxwWvVhz3C6jsa9yPsY85BQhxOSqUA5BpU4=";

  mvnParameters = lib.escapeShellArgs [
    "-Dmaven.buildNumber.revisionOnScmFailure=v${version}"
    "-Dskip.installyarn"
    "-Dskip.yarn"
    "-DskipTests"
  ];

  nativeBuildInputs = [
    antlr4_9
    fixup-yarn-lock
    nodejs
    yarn
  ];

  postPatch = ''
    rm Makefile
  '';

  postConfigure = ''
    export HOME="$PWD"

    # openmetadata-ui-core-components
    cd ~/openmetadata-ui-core-components/src/main/resources/ui
    fixup-yarn-lock yarn.lock
    yarn config --offline set yarn-offline-mirror "$yarnOfflineCacheUiCore"
    yarn install --frozen-lockfile --force --production=false \
      --ignore-engines --ignore-platform --ignore-scripts \
      --no-progress --non-interactive --offline
    patchShebangs node_modules
    yarn --offline build

    # openmetadata-ui
    cd ~/openmetadata-ui/src/main/resources/ui
    fixup-yarn-lock yarn.lock
    yarn config --offline set yarn-offline-mirror "$yarnOfflineCacheUi"
    yarn install --frozen-lockfile --force --production=false \
      --ignore-engines --ignore-platform --ignore-scripts \
      --no-progress --non-interactive --offline
    patchShebangs node_modules
    yarn --offline run js-antlr
    yarn --offline run parse-schema
    yarn --offline run build

    cd ~
  '';

  installPhase = ''
    mkdir -p $out
    tar xzf openmetadata-dist/target/openmetadata-*.tar.gz \
      --strip-components=1 -C "$out"
  '';

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--use-github-releases"
      "--version-regex=^([0-9.]+)-release"
      "--custom-dep=yarnOfflineCacheUiCore"
      "--custom-dep=yarnOfflineCacheUi"
    ];
  };

  meta = {
    description = "Unified metadata platform for data discovery, data observability, and data governance";
    homepage = "https://open-metadata.org/";
    changelog = "https://open-metadata.org/product-updates#v${version}";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [ ungeskriptet ];
    mainProgram = "fixme";
  };
}
