{ config, pkgs, ... }:

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
      name = "rose-pine";
      package = pkgs.rose-pine-hyprcursor;
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
    # development
    git
    gh # github
    direnv
    chezmoi
    vscode
    slack

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
    pyright
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
    shellcheck

    # runtime/languages
    fnm
    nodejs_20
    uv
    python3
    rustup
    gcc

    # rust tooling
    cargo-expand
    cargo-watch
    cargo-edit
    cargo-audit
    cargo-info
    rusty-man

    # networking
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
    dnsutils
    httpie # client
    siege # load test/benchmarking

    # network monitoring
    bandwhich
    iftop
    nload

    # proxy/tunnel
    proxychains
    ngrok

    # cli utils
    uutils-coreutils-noprefix # swap gnu coreutils for uutils aliases
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
    htop
    btop
    fastfetch
    mprocs
    tokei # count code tokens

    # cloud
    docker-compose
    terraform
    azure-cli
    awscli2
    doctl

    # database
    postgresql_17

    # style
    matugen
    pywal
    rose-pine-hyprcursor

    # laptop
    brightnessctl

    # media
    obs-studio
    imagemagick
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

  # program configurations
  programs = {
    zsh = {
      enable = true;
    };

    neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };

    zoxide = {
      enable = true;
      enableZshIntegration = true;
      options = [ "--cmd cd" ];
    };

    nix-index = {
      enable = true;
      enableZshIntegration = true;
    };

    home-manager.enable = true;
  };

  # default to nvim as editor
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

  # feh wrapper, so it's selectable in Rofi, and can open arbitrary folders
  home.file.".local/bin/feh-browser" = {
    text = ''
      #!/usr/bin/env bash
      dir=$(${pkgs.findutils}/bin/find ${config.home.homeDirectory} -type d | ${pkgs.rofi-wayland}/bin/rofi -dmenu -p "Select directory:")
      [ -n "$dir" ] && ${pkgs.feh}/bin/feh "$dir"
    '';
    executable = true;
  };

  xdg.desktopEntries.feh-browser = {
    name = "Feh";
    genericName = "Image Viewer";
    comment = "Browse images from selected directory";
    exec = "${config.home.homeDirectory}/.local/bin/feh-browser";
    icon = "image-x-generic";
    terminal = false;
    type = "Application";
    categories = [ "Graphics" "Photography" "Viewer" ];
  };
}
