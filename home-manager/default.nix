# Home Manager configuration
# All user applications and programs in one organized file
{ config, pkgs, pkgs-unstable, hostname, userConfig, ... }:

{
  # ============================================================================
  # BASIC CONFIGURATION
  # ============================================================================
  
  home.username = userConfig.username;
  home.homeDirectory = "/home/${userConfig.username}";
  programs.home-manager.enable = true;

  # ============================================================================
  # PACKAGES - All applications organized by category
  # ============================================================================
  
  home.packages = with pkgs; [
    # --------------------------------------------------------------------------
    # CLI UTILITIES
    # --------------------------------------------------------------------------
    fastfetch
    curl
    wget
    htop
    btop
    gh
    smartmontools

    # --------------------------------------------------------------------------
    # BROWSERS
    # --------------------------------------------------------------------------
    (google-chrome.override {
      # Disable Chrome's async CUPS backend — it holds a persistent connection to
      # CUPS that goes stale, silently failing print jobs. Closing Chrome "fixes"
      # it by dropping the stale connection. This flag forces synchronous printing
      # with a fresh connection per job.
      commandLineArgs = [ "--disable-features=CupsPrintBackend" ];
    })

    # --------------------------------------------------------------------------
    # DEVELOPMENT TOOLS
    # --------------------------------------------------------------------------
    pkgs-unstable.windsurf
    filezilla
    meld                    # Visual diff/merge tool
    insomnia                # REST API testing client (essential for Laravel APIs)

    # --------------------------------------------------------------------------
    # OFFICE & PRODUCTIVITY
    # --------------------------------------------------------------------------
    onlyoffice-desktopeditors

    # --------------------------------------------------------------------------
    # COMMUNICATION
    # --------------------------------------------------------------------------
    zapzap
    telegram-desktop

    # --------------------------------------------------------------------------
    # CLOUD & SYNC
    # --------------------------------------------------------------------------
    nextcloud-client

    # --------------------------------------------------------------------------
    # MEDIA
    # --------------------------------------------------------------------------
    mpv
    simple-scan

    # --------------------------------------------------------------------------
    # GRAPHICS & PHOTO
    # --------------------------------------------------------------------------
    gthumb          # Multi-photo print with layout wizard (Windows "Print Pictures" equivalent)
    gimp            # Image editing

    # --------------------------------------------------------------------------
    # DISK TOOLS
    # --------------------------------------------------------------------------
    gnome-disk-utility
    gsmartcontrol
    popsicle

    # --------------------------------------------------------------------------
    # SECURITY & PASSWORD MANAGEMENT
    # --------------------------------------------------------------------------
    bitwarden-desktop

    # --------------------------------------------------------------------------
    # REMOTE DESKTOP
    # --------------------------------------------------------------------------
    anydesk
  ];

  # ============================================================================
  # ENVIRONMENT & SESSION VARIABLES
  # ============================================================================
  
  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  # ============================================================================
  # PROGRAM CONFIGURATIONS
  # ============================================================================
  
  # Git configuration
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = userConfig.fullName;
        email = userConfig.email;
      };
      init.defaultBranch = "main";
      pull.rebase = true;
      push.autoSetupRemote = true;
    };
  };

  # Bash shell configuration
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -la";
      update = "nixos-update";
      upgrade = "nixos-upgrade";
      # Ollama shortcuts
      ollama-list = "ollama list";
      ollama-ps = "ollama ps";
      ollama-serve = "ollama serve";
    };
    bashrcExtra = ''
      # NixOS helpers (work across devices)
      _nixos_config_dir() {
        if [ -n "$NIXOS_CONFIG_DIR" ]; then
          printf "%s" "$NIXOS_CONFIG_DIR"
        else
          printf "%s" "${config.home.homeDirectory}/nixos-config"
        fi
      }

      nixos-update() {
        local dir
        dir="$(_nixos_config_dir)"
        if [ ! -f "$dir/flake.nix" ]; then
          echo "NixOS config not found at: $dir" >&2
          echo "Set NIXOS_CONFIG_DIR or clone the repo to that path." >&2
          return 1
        fi
        sudo nixos-rebuild switch --no-reexec --option http-connections 40 --flake "$dir#${hostname}"
      }

      nixos-upgrade() {
        local dir
        dir="$(_nixos_config_dir)"
        if [ ! -f "$dir/flake.nix" ]; then
          echo "NixOS config not found at: $dir" >&2
          echo "Set NIXOS_CONFIG_DIR or clone the repo to that path." >&2
          return 1
        fi
        if [ -f "$dir/flake.lock" ] && [ ! -w "$dir/flake.lock" ]; then
          echo "flake.lock is not writable in: $dir" >&2
          echo "Fix: sudo chown -R $USER:$USER \"$dir\"" >&2
          return 1
        fi
        (cd "$dir" && nix flake update) && \
          sudo nixos-rebuild switch --no-reexec --option http-connections 40 --flake "$dir#${hostname}"
      }
    '';
  };

  # gsmartcontrol: pkexec strips WAYLAND_DISPLAY/XDG_RUNTIME_DIR so the root window
  # never appears. Override the desktop entry to use sudo -E instead, which
  # preserves the full environment. The sudo NOPASSWD rule is in modules/core.
  home.file.".local/share/applications/gsmartcontrol.desktop".text = ''
    [Desktop Entry]
    Name=GSmartControl
    Comment=Hard Disk Drive Control Utility
    Exec=sudo -E ${pkgs.gsmartcontrol}/bin/gsmartcontrol
    Icon=gsmartcontrol
    Terminal=false
    Type=Application
    Categories=System;GTK;
  '';

  # ============================================================================
  # XDG CONFIGURATION
  # ============================================================================
  
  xdg = {
    enable = true;
    
    userDirs = {
      enable = true;
      documents = "${config.home.homeDirectory}/Documents";
      download = "${config.home.homeDirectory}/Downloads";
      pictures = "${config.home.homeDirectory}/Pictures";
      videos = "${config.home.homeDirectory}/Videos";
    };
  };

  # ============================================================================
  # STATE VERSION
  # ============================================================================
  
  home.stateVersion = "25.11";
}
