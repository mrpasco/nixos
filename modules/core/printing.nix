{ lib, pkgs, ... }:

{
  # Enable printing support
  services.printing = {
    enable = lib.mkDefault true;  # hosts can override with: services.printing.enable = false
    browsing = true;  # Enable printer browsing for local discovery
    drivers = with pkgs; [
      cups-filters   # PDF rendering backend (required for reliable Chrome → CUPS → printer)
    ];
    extraConf = ''
      # Retry jobs on transient errors instead of stopping the queue.
      ErrorPolicy retry-job

      # Prevent CUPS from exiting when idle — Chrome needs it always available.
      # Without this, socket-activation delays can cause Chrome's first-print to fail.
      IdleExitTimeout 0

      # Handle Chrome opening multiple parallel print connections.
      MaxClients 100

      # Timeout for connecting to network printers (Epson/Samsung on LAN).
      ConnectTimeout 30

      # Keep completed job history for 1 day for debugging, then auto-purge.
      PreserveJobHistory Yes
      PreserveJobFiles No
      MaxJobs 500
      MaxJobTime 3600
    '';
    # Enable CUPS web interface at http://localhost:631 for debugging
    listenAddresses = [ "localhost:631" ];
  };
  
  # Enable network printer discovery and scanner support
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
  };

  systemd.services.avahi-daemon.preStart = lib.mkAfter ''
    rm -f /run/avahi-daemon/pid || true
  '';
  
  # Enable scanner support (SANE)
  hardware.sane = {
    enable = true;
    extraBackends = [ pkgs.sane-airscan ];  # For network scanners (AirScan/eSCL)
  };
}
