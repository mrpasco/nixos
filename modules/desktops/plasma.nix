{ config, lib, pkgs, ... }:

{
  # Enable KDE Plasma 6 desktop environment
  services.desktopManager.plasma6.enable = true;

  # Keep the Plasma install focused on the desktop shell and the apps we
  # explicitly use. The full PIM suite and these optional extras are noisy on a
  # simple workstation setup.
  programs.kde-pim.enable = false;
  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    elisa
    khelpcenter
    krdp
  ];
  
  # Enable SDDM display manager with Wayland support
  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;  # Prefer Wayland session
    theme = "breeze";       # Explicitly use default Breeze theme
  };
  
  # X11/Wayland support
  services.xserver.enable = true;   # X11 input drivers and session support
  programs.xwayland.enable = true;  # X11 app compatibility on Wayland
  
  # Plasma adds the KDE/GTK desktop portals; route xdg-open through them.
  xdg.portal.xdgOpenUsePortal = true;

  # KDE Connect (phone integration - open firewall ports automatically)
  programs.kdeconnect.enable = true;

  # Small workstation extras not auto-included by plasma6.enable.
  environment.systemPackages = with pkgs; [
    kdePackages.filelight                # Disk usage analyzer
    kdePackages.kalk
    kdePackages.kompare
  ];

  # KWallet: unlock on SDDM login and on TTY/other login
  security.pam.services.sddm.enableKwallet = true;
  security.pam.services.login.enableKwallet = true;
}
