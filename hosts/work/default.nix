# Work PC specific configuration
# Only contains differences from base configuration
{ config, lib, pkgs, pkgs-unstable, inputs, hostname, userConfig, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/core
    ../../modules/desktops/plasma.nix
    ../../modules/dev/laravel.nix
    ../../modules/dev/wordpress.nix
  ];

  # Hostname
  networking.hostName = userConfig.hostnames.work;

  # WordPress dev sites — each maps to ~/Dev/<name>/ with DB wp_<name> at http://<name>.test
  services.wordpressDev = {
    enable = true;
    sites = [
      "wp1"
      # "client-project"
    ];
  };

  # No wireless or bluetooth on desktop work PC
  # (base config doesn't enable these by default)

  # Work PC hardware: Intel i9-9900KF (Coffee Lake, 8-core, no iGPU)
  # Ethernet: Intel I219-V (e1000e), Audio: Intel 200-series PCH HDA,
  # GPU: AMD Radeon R9 290, NVMe: Silicon Motion SM2263EN, USB: ASMedia ASM3142

  # VirtualBox kernel modules are incompatible with linuxPackages_latest (6.19+)
  # due to KVM namespace symbol changes — pin to LTS kernel for stability
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  boot.kernelModules = [ "e1000e" "amdgpu" ];  # Intel I219-V Ethernet + AMD GPU
  boot.blacklistedKernelModules = [ "radeon" ];  # Prevent legacy radeon driver from loading
  boot.kernelParams = [
    "radeon.cik_support=0"     # Ensure radeon does not claim CIK cards
    "amdgpu.cik_support=1"     # Enable amdgpu for CIK cards (R9 290, R9 270, HD 7xxx)
    "amdgpu.dc=1"              # Enable Display Core for better performance
    "usbcore.autosuspend=-1"   # Fix USB autosuspend issue with printers
  ];
  hardware.enableAllFirmware = true;   # Full firmware coverage (incl. non-redistributable)

  # AMD OpenCL (ROCm) for Radeon R9 290
  hardware.graphics.extraPackages = with pkgs; [ rocmPackages.clr.icd ];

  # Ollama service with AMD GPU support (using unstable version for latest models)
  services.ollama = {
    enable = true;
    package = pkgs-unstable.ollama-rocm;  # Use latest version (0.19.0) with AMD GPU support
    acceleration = "rocm";
    environmentVariables = {
      HSA_OVERRIDE_GFX_VERSION = "10.3.0";  # For R9 290/390 compatibility
    };
    host = "0.0.0.0";
    port = 11434;
  };

  # VirtualBox host (work only)
  virtualisation.virtualbox.host.enable = true;
  users.users.${userConfig.username}.extraGroups = [ "vboxusers" ];

  # Work-specific printer drivers
  services.printing.drivers = with pkgs; [
    gutenprint
    cnijfilter2
    epson-escpr
    epson-escpr2
  ];

  # GPU diagnostics and benchmarking tools
  environment.systemPackages = with pkgs; [
    radeontop      # Real-time AMD GPU usage monitor (like htop for GPU)
    mesa-demos     # glxinfo + glxgears for OpenGL driver verification
    glmark2        # OpenGL benchmark / stress test
    vulkan-tools   # vulkaninfo to inspect Vulkan driver capabilities
    opencode       # AI coding agent for terminal, IDE, and desktop
  ];

  # Desktop performance: no battery concerns on i9-9900KF
  powerManagement.cpuFreqGovernor = lib.mkForce "performance";
  # power-profiles-daemon not needed on desktop, thermald handles CPU thermals
  services.power-profiles-daemon.enable = lib.mkForce false;


  # CUPS always-running at boot — eliminates socket-activation startup latency
  # that causes Chrome's first-print IPP request to time out before CUPS is ready.
  systemd.services.cups = {
    wantedBy = lib.mkForce [ "multi-user.target" ];
  };

  # Ensure printers are configured after CUPS and network are ready.
  # switch-to-configuration kills this service (SIGTERM) during nixos-rebuild.
  # Printer configs persist in CUPS, so this only matters on first setup.
  # Marking SIGTERM as success prevents nixos-rebuild from reporting failure.
  systemd.services.ensure-printers = {
    after = [ "cups.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "cups.service" ];
    serviceConfig = {
      SuccessExitStatus = "0 1 SIGTERM";
      TimeoutStartSec = 120;
    };
  };

  # Work-specific printers
  hardware.printers = {
    ensurePrinters = [
      {
        name = "Canon_G1430";
        location = "Office";
        deviceUri = "usb://Canon/G1030%20series?serial=000EF3";
        model = "canong1030.ppd";
        ppdOptions = {
          MediaType = "plain";  # Default: plain paper
          PageSize = "A4";
        };
      }
      {
        name = "Zebra_ZD220";
        location = "Office";
        deviceUri = "usb://Zebra%20Technologies/ZTC%20ZD220-203dpi%20ZPL?serial=D4J205103283";
        model = "drv:///sample.drv/zebra.ppd";  # Zebra ZPL Label Printer
        ppdOptions = {
          PageSize = "Custom.39.99x29.99mm";  # 40x30mm labels (actual: 39.99x29.99mm)
          Resolution = "203dpi";
        };
      }
      {
        name = "Epson_L1455";
        location = "Office";
        deviceUri = "ipp://192.168.2.48:631/ipp/print";
        model = "epson-inkjet-printer-escpr/Epson-L1455_Series-epson-escpr-en.ppd";
        ppdOptions = {
          PageSize = "A4";
          MediaType = "PLAIN_NORMAL";  # Default quality: Normal (was Draft)
        };
      }
      {
        name = "Samsung_X4300LX";
        location = "Office";
        deviceUri = "ipp://192.168.2.115/ipp/printer";
        model = "everywhere";
        ppdOptions = {
          PageSize = "A4";
          MediaType = "PLAIN_NORMAL";
        };
      }
      {
        name = "Konica_Minolta_C360";
        location = "Office";
        deviceUri = "ipp://192.168.2.25/ipp/print";
        model = "everywhere";
        ppdOptions = {
          PageSize = "A4";
          ColorModel = "CMYK";
        };
      }
    ];
    ensureDefaultPrinter = "Canon_G1430";
  };

  system.stateVersion = "25.11";
}
