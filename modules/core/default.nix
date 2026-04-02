{ config, lib, pkgs, inputs, hostname, userConfig, ... }:

{
  imports = [ ./printing.nix ];
  
  # Firefox with Wayland support (system-level)
  programs.firefox.enable = true;

  # Bootloader configuration (common for all UEFI systems)
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.editor = false;           # Prevent editing kernel params at boot (security)
  boot.loader.systemd-boot.configurationLimit = 10;  # Keep last 10 generations in boot menu
  boot.loader.efi.canTouchEfiVariables = true;

  # Use latest kernel for best hardware/driver support
  boot.kernelPackages = pkgs.linuxPackages_latest;
  
  # Time zone and locale
  time.timeZone = userConfig.timezone;
  i18n.defaultLocale = userConfig.locale;

  # Keyboard layout
  console.keyMap = "us";                  # TTY login
  services.xserver.xkb.layout = "za";    # Desktop (X11/Wayland via libinput)
  
  # Define user account
  users.users.${userConfig.username} = {
    isNormalUser = true;
    description = userConfig.fullName;
    extraGroups = [ 
      "networkmanager" 
      "wheel" 
      "video"        # Screen brightness, GPU access
      "audio"        # Audio device access
      "input"        # Input device access
      "dialout"      # Serial port access
      "scanner"      # Scanner access
      "lp"           # Printer/scanner access
    ];
  };

  # Allow wheel users to launch gsmartcontrol as root while preserving the
  # Wayland/X11 display environment (needed by the sudo -E desktop entry wrapper).
  security.sudo.extraRules = [{
    groups = [ "wheel" ];
    commands = [{
      command = "${pkgs.gsmartcontrol}/bin/gsmartcontrol";
      options = [ "NOPASSWD" "SETENV" ];
    }];
  }];

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Hardware firmware and SSD optimization
  hardware.enableRedistributableFirmware = true;
  services.fstrim.enable = true;
  services.fwupd.enable = true;
  services.smartd.enable = true;  # SMART monitoring; installs smartmontools system-wide for udisks2/gnome-disk-utility
  
  # Networking (hostname set per-host)
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;
  services.tailscale.enable = true;

  # Firewall — block all inbound by default, allow only what's needed
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];  # Allow all Tailscale traffic
    allowedTCPPorts = [ ];                 # KDE Connect ports auto-opened
    allowedUDPPorts = [ ];
  };

  # Audio
  services.pulseaudio.enable = false;  # PipeWire replaces PulseAudio
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  # Power management services
  services.upower.enable = true;
  services.power-profiles-daemon.enable = true;
  
  # Graphics and hardware acceleration
  hardware.graphics = {
    enable = true;
    enable32Bit = true;  # For 32-bit apps and games
    extraPackages = with pkgs; [
      libvdpau-va-gl
    ];
  };
  
  # CPU power management
  # Note: cpuFreqGovernor is NOT set here because power-profiles-daemon manages
  # the governor dynamically. Setting both causes them to fight and lag.
  # Work overrides: forces PPD off + "performance" governor (no battery concerns).
  services.thermald.enable = true;  # Intel thermal management
  
  # Additional system services for desktop functionality
  services.accounts-daemon.enable = true;  # User account information
  programs.dconf.enable = true;            # Required by GTK apps (gnome-disk-utility, gthumb, simple-scan) to save settings
  services.earlyoom.enable = true;         # Prevent OOM freezes by killing largest process before system locks up
  programs.ssh.startAgent = true;          # SSH agent for Git/deployment key management
  
  # Automatic security updates (rebuild nightly, no auto-reboot)
  system.autoUpgrade = {
    enable = true;
    flake = "/home/${userConfig.username}/nixos-config#${hostname}";
    dates = "04:00";
    allowReboot = false;
  };

  # Nix settings
  nix = {
    settings = {
      experimental-features = [ "nix-command" "flakes" ];

      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      ];

      max-jobs = "auto";              # Use all available CPU cores
      cores = 0;                      # Let each job use all cores if needed
      log-lines = 200;
      builders-use-substitutes = true;
      auto-optimise-store = true;
      warn-dirty = false;
    };

    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };
  };
  
  # Use zram instead of disk swap for better performance
  zramSwap = {
    enable = true;
    memoryPercent = 30;
    algorithm = "zstd";
  };
  
  # VM tuning for better performance
  boot.kernel.sysctl = {
    "vm.swappiness" = 10;                # Prefer RAM over swap
    "vm.vfs_cache_pressure" = 50;        # Keep filesystem cache longer
    "vm.dirty_background_ratio" = 5;     # Start background writeback at 5% dirty pages
    "vm.dirty_ratio" = 15;               # Force synchronous writes at 15% dirty pages
  };
  
  # Use tmpfs for builds (builds in RAM for massive speed boost)
  boot.tmp.useTmpfs = true;
  boot.tmp.tmpfsSize = "25%";

}
