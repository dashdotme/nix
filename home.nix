{ pkgs, ... }:

{
  home.username = "dash";
  home.homeDirectory = "/home/dash";
  home.stateVersion = "24.11";

  programs.nix-index.enable = true; # show the package when a command isn't found

  home.packages = with pkgs; [
    curl
    wget
    bind # dns : dig, nslookup
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
    tailscale # best thing
    websocat
    # dolphin # tuis are better

    # lsps - following Helix
    nixd
    (lowPrio rust-analyzer)
    angular-language-server
    ansible-language-server
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
    typescript-language-server # js/ts... it's in go now
    jq-lsp
    lua-language-server
    marksman
    markdown-oxide
    mojo
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

    postgresql_17

    wofi
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
    deno
    bun

    uv
    python3

    ruby

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
    kubectl
    kubectx
    k9s
    helm
    terraform
    terraform-ls
    ansible

    azure-cli
    awscli2

    cmake

    htop
    btop

    fzf
    z-lua

    just
    mprocs
    tokei # count code tokens
    presenterm # markdown -> slideshow

    # teams-for-linux # not functional
    vscode
    obs-studio
  ];

  home.file.".zshrc".enable = false;
  home.file.".oh-my-zsh/custom/themes/frisk2.zsh-theme".enable = false;

  # Install oh-my-zsh from GitHub
  home.file.".oh-my-zsh" = {
    source = pkgs.fetchFromGitHub {
      owner = "ohmyzsh";
      repo = "ohmyzsh";
      rev = "master";
      sha256 = "MfNt+psdgz9l0cw0X3HFHeenQz+6oV1EXnPL8T0ffGg=";
    };
    recursive = true;
  };
  #
  # # Add custom theme for oh-my-zsh
  # home.file.".oh-my-zsh/custom/themes/frisk2.zsh-theme".text = ''
  #   PROMPT=$'
  #   %{$fg[blue]%}%/%{$reset_color%} $(git_prompt_info)$(bzr_prompt_info)%{$fg[white]%}[%n@%m]%{$reset_color%} %{$fg[white]%}[%T]%{$reset_color%} %(?:%{$fg[green]%}:%{$fg[red]%})[%?]%{$reset_color%}
  #   %{$fg_bold[black]%}>%{$reset_color%} '
  #   PROMPT2="%{$fg_bold[black]%}%_> %{$reset_color%}"
  #   GIT_CB="git::"
  #   ZSH_THEME_SCM_PROMPT_PREFIX="%{$fg[green]%}["
  #   ZSH_THEME_GIT_PROMPT_PREFIX=$ZSH_THEME_SCM_PROMPT_PREFIX$GIT_CB
  #   ZSH_THEME_GIT_PROMPT_SUFFIX="]%{$reset_color%} "
  #   ZSH_THEME_GIT_PROMPT_DIRTY=" %{$fg[red]%}*%{$fg[green]%}"
  #   ZSH_THEME_GIT_PROMPT_CLEAN=""
  # '';
  #
  # ZSH configuration
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;

    # oh-my-zsh configuration
    oh-my-zsh = {
      enable = true;
      theme = "frisk2";
      plugins = [
        "git"
        "fzf"
        "zsh-interactive-cd"
        "docker"
        "colored-man-pages"
      ];
    };

    shellAliases = {
      python = "python3";
    };

    # Custom init script with ZSH variable at the top
    initExtra = ''
      # Set ZSH variable first
      export ZSH="$HOME/.oh-my-zsh"

      # Detect OS type
      case "$(uname -s)" in
        Darwin*)
          OS_TYPE="macos"
          ;;
        Linux*)
          OS_TYPE="linux"
          ;;
        *)
          OS_TYPE="unknown"
          ;;
      esac

      export FZF_BASE=~/.fzf

      # Z-jump functionality
      if [ "$OS_TYPE" = "linux" ]; then
        # Linux-specific settings for z-jump
        if [ -f ${pkgs.z-lua}/share/z.lua ]; then
          source ${pkgs.z-lua}/share/z.lua
        fi
      fi

      # Editor preference
      if [[ -n $SSH_CONNECTION ]]; then
        export EDITOR='vim'
      else
        export EDITOR='nvim'
      fi

      # Java setup - OS specific
      if [ "$OS_TYPE" = "linux" ]; then
        # Linux Java configuration
        setopt NULL_GLOB 2>/dev/null || true
        for java_path in /usr/lib/jvm/default-java /usr/lib/jvm/java-[0-9]*-openjdk* /usr/lib/jvm/java-[0-9]*-oracle; do
          if [ -d "$java_path" ]; then
            export JAVA_HOME="$java_path"
            export PATH="$JAVA_HOME/bin:$PATH"
            break
          fi
        done
        unsetopt NULL_GLOB 2>/dev/null || true
      fi

      # Terraform completion
      if command -v terraform &>/dev/null; then
        autoload -U +X bashcompinit && bashcompinit
        complete -o nospace -C $(which terraform) terraform
      fi

      # uv completion - if installed
      if command -v uv &>/dev/null; then
        eval "$(uv generate-shell-completion zsh 2>/dev/null || true)"
      fi

      # Environment file - check if exists before sourcing
      if [ -f "$HOME/.local/bin/env" ]; then
        . "$HOME/.local/bin/env"
      fi

      # fnm (Fast Node Manager) setup
      FNM_PATH="$HOME/.local/share/fnm"
      if [ -d "$FNM_PATH" ]; then
        export PATH="$FNM_PATH:$PATH"
        command -v fnm &>/dev/null && eval "$(fnm env 2>/dev/null || true)"
        command -v fnm &>/dev/null && eval "$(fnm env --use-on-cd --shell zsh 2>/dev/null || true)"
      fi

      # GitHub username
      export GITHUB_USERNAME=dashdotme

      # Custom functions
      fcd() {
        local dir
        dir=$(find ''${1:-.} -type d 2> /dev/null | fzf +m) && cd "$dir"
      }

      if [ -f "${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
        source ${pkgs.zsh-autosuggestions}/share/zsh-autosuggestions/zsh-autosuggestions.zsh
      fi

      if [ -f "${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
        source ${pkgs.zsh-syntax-highlighting}/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
      fi

      if [ -d "${pkgs.zsh-completions}/share/zsh-completions" ]; then
        fpath=(${pkgs.zsh-completions}/share/zsh-completions $fpath)
      fi
    '';
  };

  # Program configurations
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };

  # Let Home Manager manage itself
  programs.home-manager.enable = true;
}
