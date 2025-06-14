{ pkgs, ... }:

{
  home.username = "dash";
  home.homeDirectory = "/home/dash";
  home.stateVersion = "24.11";

  # default apps to gnome dark default theming
  gtk = {
    enable = true;
    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
    cursorTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "adwaita";
    style.name = "adwaita-dark";
  };

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
    };
  };

  home.packages = with pkgs; [
    # networking
    curl
    wget
    bind # dig, nslookup
    whois
    traceroute
    nmap # service discovery
    ipcalc
    iperf3
    mtr
    tcpdump
    netcat
    socat
    sshfs
    tailscale
    websocat

    # lsps
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
    mojo
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

    postgresql_17

    uutils-coreutils-noprefix # swap gnu coreutils for uutils aliases

    # proxy/tunnel
    proxychains
    ngrok

    # http
    httpie # client
    siege # load test/benchmarking

    # network monitor
    bandwhich
    iftop
    nload

    dnsutils

    git
    gh # github
    direnv

    fnm
    nodejs_20

    uv
    python3

    rustup
    cargo-expand
    cargo-watch
    cargo-edit
    cargo-audit
    cargo-info
    rusty-man

    gcc

    shellcheck
    shfmt
    fzf
    ripgrep
    ripgrep-all
    bat
    eza # better ls
    fd
    jq
    yq
    gitui
    dua
    chezmoi

    docker-compose
    # useful but heavy - disabled by default
    # kubectl
    # kubectx
    # k9s
    # helm
    terraform
    terraform-ls

    azure-cli
    awscli2

    htop
    btop
    fastfetch

    fzf

    just
    mprocs
    tokei # count code tokens
    presenterm # markdown -> slideshow

    vscode
    obs-studio

    # style
    matugen
    pywal

    # laptop
    brightnessctl
  ];

  home.file.".zshrc".enable = false;
  home.file.".oh-my-zsh/custom/themes/frisk2.zsh-theme".enable = false;

  # Install oh-my-zsh from GitHub
  home.file.".oh-my-zsh" = {
    source = pkgs.fetchFromGitHub {
      owner = "ohmyzsh";
      repo = "ohmyzsh";
      rev = "master";
      sha256 = "rjN+/5P/q7uXSVGf/jypOCYLvoGYGPMZTy1dL9+E4Uc=";
    };
    recursive = true;
  };


  # Program configurations
  programs.zsh = {
    enable = true;
  };

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };

  programs.nix-index = {
    enable = true; # show the package when a command isn't found
    enableZshIntegration = true;
  };

  # default to nvim on open call
  xdg.mime.enable = true;
  xdg.mimeApps.enable = true;
  xdg.mimeApps.defaultApplications = {
    "text/plain" = [ "nvim.desktop" ];
  };

  xdg.desktopEntries.nvim = {
    name = "Neovim";
    genericName = "Text Editor";
    exec = "ghostty -e nvim %F";
    terminal = false;
    mimeType = [ "text/plain" "text/markdown" ];
    categories = [ "Development" "TextEditor" ];
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
