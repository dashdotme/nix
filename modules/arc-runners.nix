{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.arcRunners;

  # Bump together; hashes are of the pulled chart .tgz:
  #   helm pull oci://ghcr.io/actions/actions-runner-controller-charts/<chart> --version <v>
  #   nix hash file --sri <chart>-<v>.tgz
  arcVersion = "0.14.2";
  chartRepo = "oci://ghcr.io/actions/actions-runner-controller-charts";
  controllerChartHash = "sha256-Iidjt+2+V+q+YmzaCbtYBA7ZxwRx0yqrZQyOaCWj2Oc=";
  scaleSetChartHash = "sha256-Gi0QTlVIbK03Opwz8879CyaM1Wd0PlfqXajh3fdeDMA=";

  controllerNamespace = "arc-systems";
  runnerNamespace = "arc-runners";
  cacheNamespace = "arc-cache";
  mirrorNamespace = "arc-registry";
  controllerServiceAccount = "arc-gha-rs-controller";
  githubSecretName = "${cfg.scaleSetName}-github";

  cachePort = 3000;
  cacheUrl = "http://cache.${cacheNamespace}.svc.cluster.local:${toString cachePort}";
  cacheDir = if cfg.cache.dir != null then cfg.cache.dir
    else if cfg.storageDir != null then "${cfg.storageDir}/actions-cache"
    else "/var/lib/arc-actions-cache";

  useApp = cfg.github.app.privateKeyFile != null;
  credentialFile = if useApp then cfg.github.app.privateKeyFile else cfg.github.tokenFile;
  secretArgs = concatStringsSep " " (if useApp then [
    "--from-literal=github_app_id=${escapeShellArg cfg.github.app.id}"
    "--from-literal=github_app_installation_id=${escapeShellArg cfg.github.app.installationId}"
    "--from-file=github_app_private_key=${escapeShellArg credentialFile}"
  ] else [
    # strip the trailing newline editors add; GitHub rejects the token otherwise
    "--from-file=github_token=<(tr -d '\\n' < ${escapeShellArg credentialFile})"
  ]);

  mirrorDir = if cfg.registryMirror.dir != null then cfg.registryMirror.dir
    else if cfg.storageDir != null then "${cfg.storageDir}/registry-mirror"
    else "/var/lib/arc-registry-mirror";
  # A registry proxy fronts exactly one upstream. dockerd's --registry-mirror
  # only ever applies to docker.io, while the supabase CLI pulls from
  # public.ecr.aws unless SUPABASE_INTERNAL_IMAGE_REGISTRY names another host
  # serving the same supabase/<image> paths. ECR Public cannot sit behind the
  # proxy (it answers the proxy's blob HEAD with 401); ghcr.io/supabase, the
  # CLI's own second choice, carries the same images and can.
  mirrors = {
    docker-io = "https://registry-1.docker.io";
    ghcr-io = "https://ghcr.io";
  };
  mirrorPort = 5000;
  mirrorAddr = name: "${name}.${mirrorNamespace}.svc.cluster.local:${toString mirrorPort}";

  # null runnerImage: the nix-built image, side-loaded into containerd and
  # never pulled. Its tag is a store hash, so a rebuild is a new reference.
  localImage = cfg.runnerImage == null;
  runnerImagePackage = pkgs.callPackage ./arc-runner-image.nix { patchResultsUrl = cfg.cache.enable; };
  runnerImage = if localImage
    then "${runnerImagePackage.imageName}:${runnerImagePackage.imageTag}"
    else cfg.runnerImage;
  runnerImagePullPolicy = if localImage then "Never" else "IfNotPresent";
  # k3s re-imports a tarball it has seen before only if its mtime moved forward,
  # which never happens in the store; a hash in the file name makes every
  # rebuild a new file instead.
  runnerImageTarball = pkgs.runCommand "arc-runner-${runnerImagePackage.imageTag}.tar.zst" { }
    "ln -s ${runnerImagePackage} $out";

  # The runner overwrites ACTIONS_RESULTS_URL from the job message, so pointing
  # actions/cache (and setup-node's `cache: pnpm`) at the in-cluster cache server
  # means renaming the variable the worker writes to (UTF-16 "ACTIONS_RESULTS_URL"
  # -> "ACTIONS_RESULTS_ORL"), leaving the one set on the container intact. See
  # https://gha-cache-server.falcondev.io/getting-started. The nix-built image
  # has this baked in; a custom runnerImage is patched at container start.
  utf16 = s: concatMapStrings (c: "${c}\\x00") (map (c: "\\x${toLower (toHexString (strings.charToInt c))}") (stringToCharacters s));
  patchedRunnerCommand = ''
    sed -i 's/${utf16 "ACTIONS_RESULTS_URL"}/${utf16 "ACTIONS_RESULTS_ORL"}/g' /home/runner/bin/Runner.Worker.dll
    exec /home/runner/run.sh
  '';

  bindMounts = {
    "/var/lib/rancher" = "${cfg.storageDir}/rancher";
    "/var/lib/kubelet" = "${cfg.storageDir}/kubelet";
  };
in
{
  options.services.arcRunners = {
    enable = mkEnableOption "single-node k3s running GitHub Actions Runner Controller (ARC) runners";

    githubConfigUrl = mkOption {
      type = types.str;
      example = "https://github.com/dashdotme/flo_tracker";
      description = "Repository, organisation or enterprise URL the runners register against.";
    };

    scaleSetName = mkOption {
      type = types.str;
      default = "kinbots";
      description = "Runner scale set name. This is the value workflows use in `runs-on:`.";
    };

    minRunners = mkOption {
      type = types.ints.unsigned;
      default = 0;
      description = "Idle runners kept warm. 0 scales to zero between jobs.";
    };

    maxRunners = mkOption {
      type = types.ints.positive;
      default = 2;
      description = "Maximum concurrent runners (one job each).";
    };

    runnerImage = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "ghcr.io/actions/actions-runner:2.337.0";
      description = ''
        Runner container image, pulled from its registry. null uses the image
        built by arc-runner-image.nix (the stock runner plus the tools
        flo_tracker's workflows expect from ubuntu-latest), which is loaded
        straight into k3s from the nix store.
      '';
    };

    dindImage = mkOption {
      type = types.str;
      default = "docker:dind";
      description = "Image for the docker daemon sidecar.";
    };

    runnerResources = mkOption {
      type = types.attrs;
      default = { };
      example = { requests = { cpu = "1"; memory = "2Gi"; }; limits = { memory = "8Gi"; }; };
      description = "Kubernetes resource requests/limits for the runner container.";
    };

    github = {
      tokenFile = mkOption {
        type = types.nullOr types.str;
        default = null;
        example = "/var/lib/secrets/kinbots/github-token";
        description = ''
          File holding a GitHub PAT (fine-grained: repository Administration
          read/write). Read at runtime and loaded into a Kubernetes secret; it
          never enters the nix store. Must be a string path, not a nix path.
        '';
      };

      app = {
        id = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "GitHub App ID (or client ID). Alternative to tokenFile.";
        };
        installationId = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "GitHub App installation ID.";
        };
        privateKeyFile = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "File holding the GitHub App private key (PEM). Same handling as tokenFile.";
        };
      };
    };

    storageDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/mnt/data/kinbots";
      description = ''
        Keep all cluster state (k3s, container images, pod scratch space, the
        actions cache) under this directory by bind-mounting /var/lib/rancher
        and /var/lib/kubelet from it. Must be on a POSIX filesystem (not NTFS).
        null leaves everything on the root filesystem.
      '';
    };

    cache = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Run an in-cluster GitHub Actions cache server and route the runners'
          actions/cache traffic to it, so caches stay on the local disk instead
          of round-tripping to GitHub.
        '';
      };

      dir = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Host directory for cache data. Defaults to a directory under storageDir.";
      };

      maxSizeGB = mkOption {
        type = types.ints.positive;
        default = 20;
        description = "Cache size cap; least recently used entries are evicted beyond it.";
      };

      cleanupOlderThanDays = mkOption {
        type = types.ints.positive;
        default = 30;
        description = "Evict cache entries not accessed for this many days.";
      };

      image = mkOption {
        type = types.str;
        default = "ghcr.io/falcondev-oss/github-actions-cache-server:9.8.0";
        description = "Cache server container image.";
      };
    };

    registryMirror = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Run in-cluster pull-through caches for docker.io and ghcr.io and
          point each runner's docker daemon (and the supabase CLI) at them.
          Every runner pod starts with an empty image store, so without this
          `supabase start` downloads several GB per job.
        '';
      };

      dir = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Host directory for cached layers. Defaults to a directory under storageDir.";
      };

      retentionDays = mkOption {
        type = types.ints.positive;
        default = 30;
        description = ''
          Days a cached blob is kept before it is dropped and fetched again on
          next use. The registry has no size cap; this is what bounds the
          directory, to the images pulled within the window.
        '';
      };

      image = mkOption {
        type = types.str;
        default = "docker.io/library/registry:3.1.1";
        description = "Registry image (distribution v3: v2 cannot configure the proxy TTL).";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = (cfg.github.tokenFile != null) != useApp;
        message = "services.arcRunners: set exactly one of github.tokenFile or github.app.privateKeyFile.";
      }
      {
        assertion = useApp -> (cfg.github.app.id != null && cfg.github.app.installationId != null);
        message = "services.arcRunners: github.app needs id and installationId alongside privateKeyFile.";
      }
    ];

    environment.systemPackages = [ pkgs.kubectl pkgs.kubernetes-helm ];
    environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

    # pod <-> pod and pod <-> host traffic; the API server stays closed to the LAN
    networking.firewall.trustedInterfaces = [ "cni0" "flannel.1" ];

    services.k3s = {
      enable = true;
      role = "server";
      disable = [ "traefik" "servicelb" "metrics-server" ];
      # kubectl without sudo for admins, who could sudo to it anyway
      extraFlags = [ "--write-kubeconfig-mode=0640" "--write-kubeconfig-group=wheel" ];

      autoDeployCharts = {
        arc = {
          name = "gha-runner-scale-set-controller";
          repo = "${chartRepo}/gha-runner-scale-set-controller";
          version = arcVersion;
          hash = controllerChartHash;
          targetNamespace = controllerNamespace;
          createNamespace = true;
          values.serviceAccount.name = controllerServiceAccount;
        };

        # Needs the CRDs from the controller chart; the k3s helm controller
        # retries the install until they exist.
        ${cfg.scaleSetName} = {
          name = "gha-runner-scale-set";
          repo = "${chartRepo}/gha-runner-scale-set";
          version = arcVersion;
          hash = scaleSetChartHash;
          targetNamespace = runnerNamespace;
          createNamespace = true;
          values = {
            githubConfigUrl = cfg.githubConfigUrl;
            githubConfigSecret = githubSecretName;
            runnerScaleSetName = cfg.scaleSetName;
            minRunners = cfg.minRunners;
            maxRunners = cfg.maxRunners;
            controllerServiceAccount = {
              namespace = controllerNamespace;
              name = controllerServiceAccount;
            };
            # docker-in-docker sidecar: flo_tracker's `supabase start` needs a
            # docker daemon. This is what the chart's containerMode.type = "dind"
            # generates, written out by hand because that mode offers no way to
            # pass the daemon its mirror flags.
            template.spec = {
              initContainers = [
                {
                  name = "init-dind-externals";
                  image = runnerImage;
                  imagePullPolicy = runnerImagePullPolicy;
                  command = [ "cp" ];
                  args = [ "-r" "/home/runner/externals/." "/home/runner/tmpDir/" ];
                  volumeMounts = [{ name = "dind-externals"; mountPath = "/home/runner/tmpDir"; }];
                }
                {
                  name = "dind";
                  image = cfg.dindImage;
                  args = [
                    "dockerd"
                    "--host=unix:///var/run/docker.sock"
                    "--group=$(DOCKER_GROUP_GID)"
                  ] ++ optionals cfg.registryMirror.enable ([
                    # dockerd does the pulling and resolves through the pod's
                    # resolv.conf, so a service name works here
                    "--registry-mirror=http://${mirrorAddr "docker-io"}"
                  ] ++ map (name: "--insecure-registry=${mirrorAddr name}") (attrNames mirrors));
                  env = [{ name = "DOCKER_GROUP_GID"; value = "123"; }];
                  securityContext.privileged = true;
                  restartPolicy = "Always"; # sidecar: lives as long as the runner
                  startupProbe = {
                    exec.command = [ "docker" "info" ];
                    initialDelaySeconds = 0;
                    failureThreshold = 24;
                    periodSeconds = 5;
                  };
                  volumeMounts = [
                    { name = "work"; mountPath = "/home/runner/_work"; }
                    { name = "dind-sock"; mountPath = "/var/run"; }
                    { name = "dind-externals"; mountPath = "/home/runner/externals"; }
                  ];
                }
              ];
              containers = [{
                name = "runner";
                image = runnerImage;
                imagePullPolicy = runnerImagePullPolicy;
                command = if cfg.cache.enable && !localImage
                  then [ "/bin/bash" "-c" patchedRunnerCommand ]
                  else [ "/home/runner/run.sh" ];
                resources = cfg.runnerResources;
                env = [
                  { name = "DOCKER_HOST"; value = "unix:///var/run/docker.sock"; }
                  { name = "RUNNER_WAIT_FOR_DOCKER_IN_SECONDS"; value = "120"; }
                ] ++ optionals cfg.cache.enable [
                  # trailing slash is required
                  { name = "ACTIONS_RESULTS_URL"; value = "${cacheUrl}/"; }
                ] ++ optionals cfg.registryMirror.enable [
                  # inherited by job steps; the CLI then pulls <this>/supabase/<image>
                  { name = "SUPABASE_INTERNAL_IMAGE_REGISTRY"; value = mirrorAddr "ghcr-io"; }
                ];
                volumeMounts = [
                  { name = "work"; mountPath = "/home/runner/_work"; }
                  { name = "dind-sock"; mountPath = "/var/run"; }
                ];
              }];
              volumes = [
                { name = "work"; emptyDir = { }; }
                { name = "dind-sock"; emptyDir = { }; }
                { name = "dind-externals"; emptyDir = { }; }
              ];
            };
          };
        };
      };

      images = mkIf localImage [ runnerImageTarball ];

      manifests.arc-registry-mirror = mkIf cfg.registryMirror.enable {
        content = [
          {
            apiVersion = "v1";
            kind = "Namespace";
            metadata.name = mirrorNamespace;
          }
        ] ++ concatLists (mapAttrsToList (name: remote: [
          {
            apiVersion = "apps/v1";
            kind = "Deployment";
            metadata = { inherit name; namespace = mirrorNamespace; };
            spec = {
              replicas = 1;
              strategy.type = "Recreate"; # one writer per storage directory
              selector.matchLabels.app = name;
              template = {
                metadata.labels.app = name;
                spec = {
                  containers = [{
                    name = "registry";
                    image = cfg.registryMirror.image;
                    ports = [{ containerPort = mirrorPort; }];
                    env = [
                      { name = "REGISTRY_PROXY_REMOTEURL"; value = remote; }
                      { name = "REGISTRY_PROXY_TTL"; value = "${toString (cfg.registryMirror.retentionDays * 24)}h"; }
                      # expiry is a delete
                      { name = "REGISTRY_STORAGE_DELETE_ENABLED"; value = "true"; }
                      # the default level logs every trace span
                      { name = "REGISTRY_LOG_LEVEL"; value = "info"; }
                    ];
                    volumeMounts = [{ name = "data"; mountPath = "/var/lib/registry"; }];
                  }];
                  volumes = [{
                    name = "data";
                    hostPath = { path = "${mirrorDir}/${name}"; type = "DirectoryOrCreate"; };
                  }];
                };
              };
            };
          }
          {
            apiVersion = "v1";
            kind = "Service";
            metadata = { inherit name; namespace = mirrorNamespace; };
            spec = {
              selector.app = name;
              ports = [{ port = mirrorPort; targetPort = mirrorPort; }];
            };
          }
        ]) mirrors);
      };

      manifests.arc-actions-cache = mkIf cfg.cache.enable {
        content = [
          {
            apiVersion = "v1";
            kind = "Namespace";
            metadata.name = cacheNamespace;
          }
          {
            apiVersion = "apps/v1";
            kind = "Deployment";
            metadata = { name = "cache"; namespace = cacheNamespace; };
            spec = {
              replicas = 1;
              strategy.type = "Recreate"; # sqlite: never two writers
              selector.matchLabels.app = "cache";
              template = {
                metadata.labels.app = "cache";
                spec = {
                  containers = [{
                    name = "cache";
                    image = cfg.cache.image;
                    ports = [{ containerPort = cachePort; }];
                    env = [
                      { name = "API_BASE_URL"; value = cacheUrl; }
                      { name = "STORAGE_DRIVER"; value = "filesystem"; }
                      { name = "STORAGE_FILESYSTEM_PATH"; value = "/data/storage"; }
                      { name = "DB_DRIVER"; value = "sqlite"; }
                      { name = "DB_SQLITE_PATH"; value = "/data/cache.db"; }
                      { name = "CACHE_MAX_SIZE_BYTES"; value = toString (cfg.cache.maxSizeGB * 1024 * 1024 * 1024); }
                      { name = "CACHE_CLEANUP_OLDER_THAN_DAYS"; value = toString cfg.cache.cleanupOlderThanDays; }
                    ];
                    volumeMounts = [{ name = "data"; mountPath = "/data"; }];
                  }];
                  volumes = [{
                    name = "data";
                    hostPath = { path = cacheDir; type = "DirectoryOrCreate"; };
                  }];
                };
              };
            };
          }
          {
            apiVersion = "v1";
            kind = "Service";
            metadata = { name = "cache"; namespace = cacheNamespace; };
            spec = {
              selector.app = "cache";
              ports = [{ port = cachePort; targetPort = cachePort; }];
            };
          }
        ];
      };
    };

    # GitHub credentials: file on disk -> kubernetes secret. Re-runs whenever the
    # file changes, so rotating the token is just overwriting the file.
    systemd.services.arc-github-secret = {
      description = "Load GitHub credentials for ARC into k3s";
      after = [ "k3s.service" ];
      requires = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = credentialFile;
      path = [ pkgs.kubectl ];
      environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = 10;
      };
      script = ''
        until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 2; done
        kubectl create namespace ${runnerNamespace} --dry-run=client -o yaml | kubectl apply -f -
        kubectl -n ${runnerNamespace} create secret generic ${githubSecretName} ${secretArgs} \
          --dry-run=client -o yaml | kubectl apply -f -
      '';
    };

    systemd.paths.arc-github-secret = {
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathChanged = credentialFile;
    };

    # Relocate cluster state. The nixpkgs k3s module hardcodes /var/lib/rancher
    # for manifests and charts, so bind-mount rather than pass --data-dir.
    systemd.services.arc-storage-dirs = mkIf (cfg.storageDir != null) {
      description = "Create ARC storage directories";
      unitConfig = {
        DefaultDependencies = false;
        RequiresMountsFor = cfg.storageDir;
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = "mkdir -p ${escapeShellArgs (attrValues bindMounts)}";
    };

    systemd.mounts = mkIf (cfg.storageDir != null) (mapAttrsToList (where: what: {
      inherit what where;
      type = "none";
      options = "bind,nofail"; # nofail: not ordered before local-fs.target
      requires = [ "arc-storage-dirs.service" ];
      after = [ "arc-storage-dirs.service" ];
    }) bindMounts);

    systemd.services.k3s.unitConfig.RequiresMountsFor =
      mkIf (cfg.storageDir != null) (attrNames bindMounts);

    # The k3s module links manifests, charts and images into /var/lib/rancher
    # via tmpfiles, which runs before the bind mount exists (at boot, and on the
    # activation that first adds it); the mount then hides them. Link again on top.
    systemd.services.arc-k3s-links = mkIf (cfg.storageDir != null) {
      description = "Link k3s manifests into the relocated state directory";
      requiredBy = [ "k3s.service" ];
      before = [ "k3s.service" ];
      unitConfig.RequiresMountsFor = attrNames bindMounts;
      serviceConfig.Type = "oneshot";
      script = "${config.systemd.package}/bin/systemd-tmpfiles --create --prefix=/var/lib/rancher";
    };
  };
}
