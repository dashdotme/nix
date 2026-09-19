# self-hosted github actions runners: single-node k3s running the actions runner
# controller (arc), which starts one throwaway pod per job and scales to zero.
# workflows opt in with `runs-on: <scaleSetName>`. inspect with `kubectl get pods -A`
#
# sections, in order:
#   options
#   k3s
#   runner image        (built in ./arc-runner-image.nix)
#   arc charts + runner pod
#   actions cache
#   registry mirrors
#   github token
#   storage relocation
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.arcRunners;

  # values that more than one place must agree on. a mismatch in any of these
  # still evaluates, builds and deploys; it only fails at runtime
  namespaces = {
    controller = "arc-systems";
    runners = "arc-runners";
    cache = "arc-cache";
    mirror = "arc-registry";
  };
  controllerServiceAccount = "arc-gha-rs-controller";
  githubSecret = "${cfg.scaleSetName}-github"; # written by the github token section, read by the chart

  # in-cluster addresses: each is served by one section and used by the runner pod
  cachePort = 3000;
  cacheUrl = "http://cache.${namespaces.cache}.svc.cluster.local:${toString cachePort}";
  mirrorPort = 5000;
  mirrorHost = name: "${name}.${namespaces.mirror}.svc.cluster.local:${toString mirrorPort}";

  image = pkgs.callPackage ./arc-runner-image.nix { patchResultsUrl = cfg.cache.enable; };
  imageRef = "${image.imageName}:${image.imageTag}";

  # cache + mirror data goes under storageDir when that is set
  dataDir = name:
    if cfg.storageDir != null then "${cfg.storageDir}/${name}" else "/var/lib/arc-${name}";
in
{
  # === options ===
  options.services.arcRunners = {
    enable = mkEnableOption "single-node k3s running GitHub Actions Runner Controller (ARC) runners";

    githubConfigUrl = mkOption {
      type = types.str;
      example = "https://github.com/dashdotme/flo_tracker";
      description = "Repository, organisation or enterprise URL the runners register against.";
    };

    githubTokenFile = mkOption {
      type = types.str;
      example = "/var/lib/secrets/kinbots/github-token";
      description = ''
        File holding a GitHub PAT (fine-grained: repository Administration
        read/write). Read at runtime and loaded into a Kubernetes secret; it
        never enters the nix store. Must be a string path, not a nix path.
      '';
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

    storageDir = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "/mnt/kinbots";
      description = ''
        Keep all cluster state (k3s, container images, pod scratch space, the
        actions cache, the registry mirrors) under this directory instead of
        on the root filesystem. Must be on a POSIX filesystem (not NTFS).
      '';
    };

    cache.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Serve actions/cache from an in-cluster server instead of GitHub.";
    };

    cache.maxSizeGB = mkOption {
      type = types.ints.positive;
      default = 20;
      description = "Cache size cap; least recently used entries are evicted beyond it.";
    };

    registryMirror.enable = mkOption {
      type = types.bool;
      default = true;
      description = "Run pull-through caches for docker.io and ghcr.io and point the runners at them.";
    };
  };

  config = mkIf cfg.enable {

    # === k3s ===
    environment.systemPackages = [ pkgs.kubectl pkgs.kubernetes-helm ];
    environment.variables.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

    # pod <-> pod and pod <-> host traffic; the api server stays closed to the lan
    networking.firewall.trustedInterfaces = [ "cni0" "flannel.1" ];

    services.k3s = {
      enable = true;
      role = "server";
      disable = [ "traefik" "servicelb" "metrics-server" ];
      # kubectl without sudo for admins, who could sudo to it anyway
      extraFlags = [ "--write-kubeconfig-mode=0640" "--write-kubeconfig-group=wheel" ];
    };

    # === runner image ===
    # handed to k3s as a file and never pulled (hence imagePullPolicy Never
    # below). its tag is a store hash, so a rebuilt image is always a new
    # reference for the pod.
    # k3s re-imports a tarball it has seen before only if its mtime moved
    # forward, which never happens in the store; a hash in the file name makes
    # every rebuild a new file instead
    services.k3s.images = [
      (pkgs.runCommand "arc-runner-${image.imageTag}.tar.zst" { } "ln -s ${image} $out")
    ];

    # === arc charts + runner pod ===
    services.k3s.autoDeployCharts =
      let
        # bump the version and both hashes together; each hash is of the pulled .tgz:
        #   helm pull <chartRepo>/<chart> --version <v> && nix hash file --sri <chart>-<v>.tgz
        version = "0.14.2";
        chartRepo = "oci://ghcr.io/actions/actions-runner-controller-charts";

        # the pod each job runs in: a runner plus a docker-in-docker sidecar
        # (flo_tracker's `supabase start` needs a docker daemon). this is what
        # the chart's containerMode.type = "dind" generates, written out by hand
        # because that mode offers no way to pass the daemon its mirror flags
        runnerPod = {
          initContainers = [
            {
              name = "init-dind-externals";
              image = imageRef;
              imagePullPolicy = "Never";
              command = [ "cp" ];
              args = [ "-r" "/home/runner/externals/." "/home/runner/tmpDir/" ];
              volumeMounts = [{ name = "dind-externals"; mountPath = "/home/runner/tmpDir"; }];
            }
            {
              name = "dind";
              image = "docker:dind";
              args = [
                "dockerd"
                "--host=unix:///var/run/docker.sock"
                "--group=$(DOCKER_GROUP_GID)"
              ] ++ optionals cfg.registryMirror.enable [
                # dockerd does the pulling and resolves through the pod's
                # resolv.conf, so a service name works here. --registry-mirror
                # only ever applies to docker.io
                "--registry-mirror=http://${mirrorHost "docker-io"}"
                # the mirrors are plain http: one flag per mirror in the registry mirrors section
                "--insecure-registry=${mirrorHost "docker-io"}"
                "--insecure-registry=${mirrorHost "ghcr-io"}"
              ];
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
            image = imageRef;
            imagePullPolicy = "Never";
            command = [ "/home/runner/run.sh" ];
            resources = { }; # no requests or limits
            env = [
              { name = "DOCKER_HOST"; value = "unix:///var/run/docker.sock"; }
              { name = "RUNNER_WAIT_FOR_DOCKER_IN_SECONDS"; value = "120"; }
            ] ++ optionals cfg.cache.enable [
              # the runner overwrites this from the job message; it only sticks
              # because the image patches Runner.Worker.dll (see
              # arc-runner-image.nix). trailing slash is required
              { name = "ACTIONS_RESULTS_URL"; value = "${cacheUrl}/"; }
            ] ++ optionals cfg.registryMirror.enable [
              # inherited by job steps; the supabase cli then pulls
              # <this>/supabase/<image> instead of going to public.ecr.aws
              { name = "SUPABASE_INTERNAL_IMAGE_REGISTRY"; value = mirrorHost "ghcr-io"; }
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
      in
      {
        arc = {
          name = "gha-runner-scale-set-controller";
          repo = "${chartRepo}/gha-runner-scale-set-controller";
          inherit version;
          hash = "sha256-Iidjt+2+V+q+YmzaCbtYBA7ZxwRx0yqrZQyOaCWj2Oc=";
          targetNamespace = namespaces.controller;
          createNamespace = true;
          values.serviceAccount.name = controllerServiceAccount;
        };

        # needs the crds from the controller chart; the k3s helm controller
        # retries the install until they exist
        ${cfg.scaleSetName} = {
          name = "gha-runner-scale-set";
          repo = "${chartRepo}/gha-runner-scale-set";
          inherit version;
          hash = "sha256-Gi0QTlVIbK03Opwz8879CyaM1Wd0PlfqXajh3fdeDMA=";
          targetNamespace = namespaces.runners;
          createNamespace = true;
          values = {
            githubConfigUrl = cfg.githubConfigUrl;
            githubConfigSecret = githubSecret;
            runnerScaleSetName = cfg.scaleSetName;
            minRunners = cfg.minRunners;
            maxRunners = cfg.maxRunners;
            controllerServiceAccount = {
              namespace = namespaces.controller;
              name = controllerServiceAccount;
            };
            template.spec = runnerPod;
          };
        };
      };

    # === actions cache ===
    # actions/cache (and setup-node's `cache: pnpm`) served from the local disk
    # instead of round-tripping to github. runners reach it at cacheUrl
    services.k3s.manifests.arc-actions-cache = mkIf cfg.cache.enable {
      content = [
        {
          apiVersion = "v1";
          kind = "Namespace";
          metadata.name = namespaces.cache;
        }
        {
          apiVersion = "apps/v1";
          kind = "Deployment";
          metadata = { name = "cache"; namespace = namespaces.cache; };
          spec = {
            replicas = 1;
            strategy.type = "Recreate"; # sqlite: never two writers
            selector.matchLabels.app = "cache";
            template = {
              metadata.labels.app = "cache";
              spec = {
                containers = [{
                  name = "cache";
                  image = "ghcr.io/falcondev-oss/github-actions-cache-server:9.8.0";
                  ports = [{ containerPort = cachePort; }];
                  env = [
                    { name = "API_BASE_URL"; value = cacheUrl; }
                    { name = "STORAGE_DRIVER"; value = "filesystem"; }
                    { name = "STORAGE_FILESYSTEM_PATH"; value = "/data/storage"; }
                    { name = "DB_DRIVER"; value = "sqlite"; }
                    { name = "DB_SQLITE_PATH"; value = "/data/cache.db"; }
                    { name = "CACHE_MAX_SIZE_BYTES"; value = toString (cfg.cache.maxSizeGB * 1024 * 1024 * 1024); }
                    # evict entries not accessed for this long
                    { name = "CACHE_CLEANUP_OLDER_THAN_DAYS"; value = "30"; }
                  ];
                  volumeMounts = [{ name = "data"; mountPath = "/data"; }];
                }];
                volumes = [{
                  name = "data";
                  hostPath = { path = dataDir "actions-cache"; type = "DirectoryOrCreate"; };
                }];
              };
            };
          };
        }
        {
          apiVersion = "v1";
          kind = "Service";
          metadata = { name = "cache"; namespace = namespaces.cache; };
          spec = {
            selector.app = "cache";
            ports = [{ port = cachePort; targetPort = cachePort; }];
          };
        }
      ];
    };

    # === registry mirrors ===
    # every runner pod starts with an empty docker image store, so without
    # these `supabase start` downloads several gb per job. runners reach them
    # at mirrorHost <name>.
    # docker.io is what dockerd's --registry-mirror covers. the supabase cli
    # pulls from public.ecr.aws unless SUPABASE_INTERNAL_IMAGE_REGISTRY names
    # another host serving the same supabase/<image> paths. ecr public cannot
    # sit behind the proxy (it answers the proxy's blob HEAD with 401);
    # ghcr.io/supabase, the cli's own second choice, carries the same images
    # and can
    services.k3s.manifests.arc-registry-mirror =
      let
        # a registry proxy fronts exactly one upstream, so each mirror is its
        # own deployment + service
        mirror = name: upstream: [
          {
            apiVersion = "apps/v1";
            kind = "Deployment";
            metadata = { inherit name; namespace = namespaces.mirror; };
            spec = {
              replicas = 1;
              strategy.type = "Recreate"; # one writer per storage directory
              selector.matchLabels.app = name;
              template = {
                metadata.labels.app = name;
                spec = {
                  containers = [{
                    name = "registry";
                    # distribution v3: v2 cannot configure the proxy ttl
                    image = "docker.io/library/registry:3.1.1";
                    ports = [{ containerPort = mirrorPort; }];
                    env = [
                      { name = "REGISTRY_PROXY_REMOTEURL"; value = upstream; }
                      # 30 days, after which a blob is dropped and fetched again
                      # on next use. the registry has no size cap; this is what
                      # bounds the directory, to the images pulled within the window
                      { name = "REGISTRY_PROXY_TTL"; value = "720h"; }
                      # expiry is a delete
                      { name = "REGISTRY_STORAGE_DELETE_ENABLED"; value = "true"; }
                      # the default level logs every trace span
                      { name = "REGISTRY_LOG_LEVEL"; value = "info"; }
                    ];
                    volumeMounts = [{ name = "data"; mountPath = "/var/lib/registry"; }];
                  }];
                  volumes = [{
                    name = "data";
                    hostPath = { path = "${dataDir "registry-mirror"}/${name}"; type = "DirectoryOrCreate"; };
                  }];
                };
              };
            };
          }
          {
            apiVersion = "v1";
            kind = "Service";
            metadata = { inherit name; namespace = namespaces.mirror; };
            spec = {
              selector.app = name;
              ports = [{ port = mirrorPort; targetPort = mirrorPort; }];
            };
          }
        ];
      in
      mkIf cfg.registryMirror.enable {
        content = [
          {
            apiVersion = "v1";
            kind = "Namespace";
            metadata.name = namespaces.mirror;
          }
        ]
        # a new mirror also needs an --insecure-registry flag in the dind args above
        ++ mirror "docker-io" "https://registry-1.docker.io"
        ++ mirror "ghcr-io" "https://ghcr.io";
      };

    # === github token ===
    # file on disk -> kubernetes secret. re-runs whenever the file changes, so
    # rotating the token is just overwriting the file
    systemd.services.arc-github-secret = {
      description = "Load GitHub credentials for ARC into k3s";
      after = [ "k3s.service" ];
      requires = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      unitConfig.ConditionPathExists = cfg.githubTokenFile;
      path = [ pkgs.kubectl ];
      environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = 10;
      };
      # tr: strip the trailing newline editors add; github rejects the token otherwise
      script = ''
        until kubectl get --raw /readyz >/dev/null 2>&1; do sleep 2; done
        kubectl create namespace ${namespaces.runners} --dry-run=client -o yaml | kubectl apply -f -
        kubectl -n ${namespaces.runners} create secret generic ${githubSecret} --from-file=github_token=<(tr -d '\n' < ${escapeShellArg cfg.githubTokenFile}) \
          --dry-run=client -o yaml | kubectl apply -f -
      '';
    };

    systemd.paths.arc-github-secret = {
      wantedBy = [ "multi-user.target" ];
      pathConfig.PathChanged = cfg.githubTokenFile;
    };

    # === storage relocation ===
    # only when storageDir is set. the nixpkgs k3s module hardcodes
    # /var/lib/rancher for manifests and charts, so bind-mount the state dirs
    # from storageDir rather than pass --data-dir. start order:
    #   storageDir's own mount -> arc-storage-dirs -> bind mounts -> arc-k3s-links -> k3s
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
      script = "mkdir -p ${escapeShellArgs [ "${cfg.storageDir}/kubelet" "${cfg.storageDir}/rancher" ]}";
    };

    systemd.mounts = mkIf (cfg.storageDir != null) [
      {
        what = "${cfg.storageDir}/kubelet"; # pod scratch space
        where = "/var/lib/kubelet";
        type = "none";
        options = "bind,nofail"; # nofail: not ordered before local-fs.target
        requires = [ "arc-storage-dirs.service" ];
        after = [ "arc-storage-dirs.service" ];
      }
      {
        what = "${cfg.storageDir}/rancher"; # k3s state, container images
        where = "/var/lib/rancher";
        type = "none";
        options = "bind,nofail"; # as above
        requires = [ "arc-storage-dirs.service" ];
        after = [ "arc-storage-dirs.service" ];
      }
    ];

    systemd.services.k3s.unitConfig.RequiresMountsFor =
      mkIf (cfg.storageDir != null) [ "/var/lib/kubelet" "/var/lib/rancher" ];

    # the k3s module links manifests, charts and images into /var/lib/rancher
    # via tmpfiles, which runs before the bind mount exists (at boot, and on the
    # activation that first adds it); the mount then hides them. link again on top
    systemd.services.arc-k3s-links = mkIf (cfg.storageDir != null) {
      description = "Link k3s manifests into the relocated state directory";
      requiredBy = [ "k3s.service" ];
      before = [ "k3s.service" ];
      unitConfig.RequiresMountsFor = [ "/var/lib/kubelet" "/var/lib/rancher" ];
      serviceConfig.Type = "oneshot";
      script = "${config.systemd.package}/bin/systemd-tmpfiles --create --prefix=/var/lib/rancher";
    };
  };
}
