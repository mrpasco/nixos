{ config, lib, pkgs, ... }:

{
  # Enable KDE Plasma 6 desktop environment
  services.desktopManager.plasma6.enable = true;
  
  # Enable SDDM display manager with Wayland support
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;  # Prefer Wayland session
    theme = "breeze";       # Explicitly use default Breeze theme
  };
  
  # X11/Wayland support
  services.xserver.enable = true;   # X11 input drivers and session support
  programs.xwayland.enable = true;  # X11 app compatibility on Wayland
  
  # XDG Desktop Portal (file chooser, screen sharing, etc)
  # xdg-desktop-portal-kde is auto-added by plasma6; gtk is a fallback for non-KDE apps
  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    xdgOpenUsePortal = true;
  };

  # KDE Connect (phone integration - open firewall ports automatically)
  programs.kdeconnect.enable = true;

  # Extras not auto-included by plasma6.enable
  # (dolphin, konsole, ark, spectacle, gwenview, okular, kcalc,
  #  plasma-systemmonitor, kinfocenter, plasma-disks, sddm-kcm, plasma-nm
  #  are all bundled automatically)
  environment.systemPackages = with pkgs; [
    kdePackages.kate                     # Text editor
    kdePackages.partitionmanager         # Partition manager
    kdePackages.filelight                # Disk usage analyzer
    kdePackages.plasma-browser-integration
  ];

  # KWallet: unlock on SDDM login and on TTY/other login
  security.pam.services.sddm.enableKwallet = true;
  security.pam.services.login.enableKwallet = true;
}
