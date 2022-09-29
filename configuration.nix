{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # add grub for boot
  boot.loader.grub.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub.useOSProber = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = false;
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = "nodev"; #"/dev/sda"; # or "nodev" for efi only

  # enable network
  networking.hostName = "pcXXX"; # Define your hostname.
  networking.networkmanager.enable = true;  # Easiest to use and most distros use this by default.

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # disable root passwd, remove this after 1st boot
  users.users.root.initialHashedPassword = "";
  # add admin user
  users.users.admin = {
    isNormalUser = true;
    description = "admin";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Initial packages installed
  environment.systemPackages = with pkgs; [
    vim
    wget
    curl
  ];

  system.stateVersion = "22.05";
}

