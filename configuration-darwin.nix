{ pkgs, self, ... }:
{

  nix = {
      package = pkgs.nixVersions.latest;
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
      optimise.automatic = true;
      gc = {
        automatic = true;
        interval = { Weekday = 0; Hour = 2; Minute = 0; };
        options = "--delete-older-than 30d";
      };
  };

  nixpkgs.hostPlatform = "aarch64-darwin";
  nixpkgs.config = {
    allowUnfree = true;
    permittedInsecurePackages = ["electron-33.4.11"];
  };

  system.primaryUser = "dashvallance";

  # List packages installed in system profile. To search by name, run:
  # $ nix-env -qaP | grep wget
  environment.systemPackages = with pkgs; [
    neovim
    jq
    yq
    tmux

    fd
    ripgrep
    tree
    eza
    fzf
    zoxide
    htop
    btop
    fastfetch

    dos2unix

    rsync
    wget
    parallel

    # network monitor
    bandwhich
    iftop
    nload

    # lsps
    terraform-ls
    shellcheck
    shfmt
    nixd
    (lowPrio rust-analyzer)
    angular-language-server
    bash-language-server
    clang-tools # clangd - c, c++
    omnisharp-roslyn # OmniSharp, c#
    elixir-ls
    gopls
    golangci-lint-langserver
    haskellPackages.haskell-language-server
    terraform-ls
    helm-ls
    hyprls
    vscode-langservers-extracted # html, css, json, eslint
    typescript-language-server
    jq-lsp
    lua-language-server
    marksman
    markdown-oxide
    python312Packages.python-lsp-server
    ruff
    svelte-language-server
    vue-language-server
    yaml-language-server
    zls

    # formatters
    nixpkgs-fmt
    nodePackages.prettier
    nodePackages.eslint
    csharpier
    shfmt
    yamlfmt
    taplo
    sqlfluff

  ];

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "none"; # set to uninstall or zap later
    };

    brews = [
      "azcopy"
      "azure-cli"
      "azure-functions-core-tools@4"

      "mssql-tools"
      "mssql-tools18"
      # "sqlcmd" # conflicts, bundled above

      "terraform"
      "packer"

      "powershell"

      # macOS-specific utilities
      "duti"                 # File associations
      "showkey"              # Key display utility
      "smartmontools"        # Hardware monitoring

      # image/video (dependency hell)
      # "ffmpeg"
      # "imagemagick"

      "postgresql@14"
      "postgresql@15"
      "postgresql@16"

      "pyenv-virtualenv"

      "icu4c@76"
      "python@3.13"

      "libmemcached"

      "clamav"

      "fnm"
      "chezmoi"
      "podman"

      "sha2"
      "python-packaging"
      "bash-language-server"
    ];

    casks = [
      "aerospace"
      "dotnet-sdk"
      "ghostty@tip"
      "orbstack"
      "visual-studio-code"
    ];
  };

  # Set Git commit hash for darwin-version.
  system.configurationRevision = self.rev or self.dirtyRev or null;

  # Used for backwards compatibility, please read the changelog before changing.
  # $ darwin-rebuild changelog
  system.stateVersion = 6;
}
