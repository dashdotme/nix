# Runner image for services.arcRunners: the stock actions-runner image plus the
# tools flo_tracker's workflows take for granted on ubuntu-latest. Built
# entirely by nix and side-loaded into k3s, so there is no registry to maintain.
{ lib
, dockerTools
, runCommand
, writeShellScriptBin
, fetchurl
, unzip
, fontconfig
, jq
, nodejs_22
, zstd
, postgresql
, google-chrome
, liberation_ttf
, dejavu_fonts
, noto-fonts-color-emoji
  # Rename ACTIONS_RESULTS_URL inside Runner.Worker.dll (see arc-runners.nix)
, patchResultsUrl ? true
}:

let
  # Bump together with the digest/hash:
  #   nix run nixpkgs#nix-prefetch-docker -- --image-name ghcr.io/actions/actions-runner --image-tag <v>
  runnerVersion = "2.337.0";
  base = dockerTools.pullImage {
    imageName = "ghcr.io/actions/actions-runner";
    imageDigest = "sha256:e5496277be5d09bc968b3d64911b74e219ac4a3f2edce956a3ecf9271bea1ef4";
    hash = "sha256-8kvFXvzLgLUssnF/ktQ3cx2/0omYybEZP9sSc6n5cJY=";
    finalImageName = "ghcr.io/actions/actions-runner";
    finalImageTag = runnerVersion;
  };

  utf16 = s: lib.concatMapStrings (c: "\\x${lib.toLower (lib.toHexString (lib.strings.charToInt c))}\\x00") (lib.stringToCharacters s);
  dllPath = "home/runner/bin/Runner.Worker.dll";

  # Fails the build, rather than silently doing nothing, if a runner bump
  # changes how the variable name is stored.
  patchedWorkerDll = runCommand "Runner.Worker.dll" { nativeBuildInputs = [ jq ]; } ''
    for layer in $(tar -xOf ${base} manifest.json | jq -r '.[0].Layers[]'); do
      if tar -xOf ${base} "$layer" | tar -x ${dllPath} 2>/dev/null; then break; fi
    done
    export LC_ALL=C
    sed 's/${utf16 "ACTIONS_RESULTS_URL"}/${utf16 "ACTIONS_RESULTS_ORL"}/g' ${dllPath} > $out
    grep -qaP '${utf16 "ACTIONS_RESULTS_ORL"}' $out
    if grep -qaP '${utf16 "ACTIONS_RESULTS_URL"}' $out; then echo "unpatched name still present"; exit 1; fi
  '';

  # Upstream release binaries at exactly the versions flo_tracker's workflows
  # pin, which is what lets those workflows skip their setup steps on this
  # runner. They assert the version when they do, so a bump there that is not
  # mirrored here fails the job instead of running a stale tool.
  pinnedTools = runCommand "arc-runner-pinned-tools" { nativeBuildInputs = [ unzip ]; } ''
    mkdir -p $out/bin
    unzip -q ${fetchurl {
      url = "https://github.com/denoland/deno/releases/download/v2.7.14/deno-x86_64-unknown-linux-gnu.zip";
      hash = "sha256-Mofv71NgaWZGnLagJ4Eye+IrkIlZOX+XbimW3Btkrg8=";
    }} deno -d $out/bin
    tar -xzf ${fetchurl {
      url = "https://github.com/supabase/cli/releases/download/v2.117.0/supabase_linux_amd64.tar.gz";
      hash = "sha256-acBfhbnkfucG0w8abKilJrTjN7/RLH7x71ItJOcoDSQ=";
    }} -C $out/bin supabase
    tar -xzf ${fetchurl {
      url = "https://github.com/grafana/k6/releases/download/v2.0.0/k6-v2.0.0-linux-amd64.tar.gz";
      hash = "sha256-Kuh9l29s26Fxhb3ZgNiBmjqY6QksbwY4zVgnLs78i5A=";
    }} --strip-components=1 -C $out/bin k6-v2.0.0-linux-amd64/k6
    chmod +x $out/bin/*
  '';

  # The slim image has no fonts, and without them Chrome renders tofu. These
  # are the families ubuntu-latest ships.
  fonts = [ liberation_ttf dejavu_fonts noto-fonts-color-emoji ];

  # Pods get a 64M /dev/shm, which Chrome outgrows on real pages.
  chrome = writeShellScriptBin "google-chrome" ''
    exec ${google-chrome}/bin/google-chrome-stable --disable-dev-shm-usage "$@"
  '';

  pathLinks = {
    google-chrome = "${chrome}/bin/google-chrome";
    psql = "${postgresql}/bin/psql";
    zstd = "${zstd}/bin/zstd";
    node = "${nodejs_22}/bin/node";
    npm = "${nodejs_22}/bin/npm";
    npx = "${nodejs_22}/bin/npx";
    corepack = "${nodejs_22}/bin/corepack";
    # glibc-linked upstream builds: they run against the Ubuntu base, as they
    # do when the setup actions download them
    deno = "${pinnedTools}/bin/deno";
    supabase = "${pinnedTools}/bin/supabase";
    k6 = "${pinnedTools}/bin/k6";
  };
in
dockerTools.buildLayeredImage {
  name = "localhost/arc-runner";
  tag = null; # store hash: a rebuilt image is always a new reference
  fromImage = base;
  compressor = "zstd";

  # Only Env is inherited from the base image.
  config = {
    User = "runner";
    WorkingDir = "/home/runner";
  };

  # Tools are linked into /usr/local/bin rather than passed as `contents`,
  # which would replace Ubuntu's /bin -> usr/bin symlink with a directory.
  # The directory is world-writable as on GitHub-hosted runners: `corepack
  # enable` drops its shims next to the corepack binary, and load-test.yml
  # untars k6 there, both as the unprivileged runner user.
  fakeRootCommands = ''
    mkdir -p usr/local/bin
    chmod 1777 usr/local/bin
    ${lib.concatStrings (lib.mapAttrsToList (name: target: ''
      ln -s ${target} usr/local/bin/${name}
    '') pathLinks)}
    # nixpkgs' Chrome brings its own fonts.conf, which reads these two FHS
    # paths; conf.d is what maps serif/monospace/emoji to real families
    mkdir -p usr/share/fonts etc/fonts
    ${lib.concatMapStrings (font: ''
      ln -s ${font}/share/fonts usr/share/fonts/${font.pname}
    '') fonts}
    ln -s ${fontconfig.out}/etc/fonts/conf.d etc/fonts/conf.d
  '' + lib.optionalString patchResultsUrl ''
    # ownership and modes as in the base image; a layer's directory entries
    # replace the metadata of the directories below them
    mkdir -p home/runner/bin
    chown 1001:1001 home/runner && chmod 777 home/runner
    chown 1001:123 home/runner/bin
    install -o 1001 -g 123 -m 644 ${patchedWorkerDll} ${dllPath}
  '';
}
