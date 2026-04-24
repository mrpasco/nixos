# Home PC specific configuration
# Only contains differences from base configuration
{ config, lib, pkgs, inputs, hostname, userConfig, ... }:

{
  imports = [
    ./hardware.nix
    ../../modules/core
    ../../modules/desktops/plasma.nix
  ];

  # Hostname
  networking.hostName = userConfig.hostnames.home;

  # Enable wireless and bluetooth (laptop features)
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  environment.systemPackages = [ pkgs.kdePackages.bluedevil ];

  # Intel GPU hardware video acceleration (VA-API)
  # Without this, all video decode and KDE compositing runs on CPU → severe lag
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver   # VA-API driver for Broadwell+ (iHD)
    intel-vaapi-driver   # VA-API driver for older Intel (i965, fallback)
    vpl-gpu-rt           # Intel Quick Sync Video (oneVPL runtime)
  ];

  # No printers at home — disable CUPS (SANE/scanning still works via hardware.sane)
  services.printing.enable = false;

  system.stateVersion = "25.11";

}
