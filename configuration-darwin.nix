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
    permittedInsecurePackages = [ "electron-33.4.11" ];
  };

  system.primaryUser = "dashvallance";

  # below currently serves in place of a home manager config for darwin
  environment.systemPackages = with pkgs; [
    # basics
    neovim
    jq
    yq
    tmux
    lftp
    fd
    ripgrep
    tree
    eza
    fzf
    zoxide
    htop
    btop
    fastfetch
    colordiff
    dos2unix
    curl
    gnugrep
    rsync
    wget
    parallel
    syncthing
    fnm
    chezmoi
    rclone

    # nix
    direnv

    # network
    bandwhich
    iftop
    nload
    ipcalc

    # lsps
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
    pyright
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
    stylua

  ];

  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "uninstall"; # set to uninstall or zap later
    };

    brews = [

      "azcopy"
      "azure-cli"
      "azure-functions-core-tools@4"

      "microsoft/mssql-release/mssql-tools"
      "microsoft/mssql-release/mssql-tools18"

      "hashicorp/tap/terraform"
      "hashicorp/tap/packer"

      "powershell"

      "duti" # CLI - fix file associations
      "smartmontools" # hardware monitoring

      "postgresql@14"
      "postgresql@15"
      "postgresql@16"

      "pyenv-virtualenv"

      "python@3.13"

      "libmemcached"

      "clamav"

      "podman"

    ];

    casks = [
      "aerospace"
      "dotnet-sdk"
      "ghostty@tip"
      "orbstack"
      "visual-studio-code"
    ];

    taps = [
      "hashicorp/tap"
      "microsoft/mssql-release"
      "nikitabobko/tap"
    ];

  };

  system.configurationRevision = self.rev or self.dirtyRev or null;

  system.stateVersion = 6;
}
