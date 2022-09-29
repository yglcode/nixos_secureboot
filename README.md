## Notes: install NixOS in PC with SecureBoot enabled ##

### 1. summary: ###
   + NixOS doesn't have distribution for secure boot yet
   + ubuntu/debian/... support secure boot thru uefi/grub shim
   + we can first install ubuntu, then install nixOS from within ubuntu
   + disable checking at shim level thru mokutil and use shim to boot nixOS
   + partition/mount difference between nixOS and ubuntu:
       + in ubuntu, EFI partition is mounted under /boot/EFI
       + in nixOS, it is mounted under /boot
   + reference:
     + nixOS manual, section 2.5.4 Installing from another Linux distribution
     + nixos-infect (https://github.com/elitak/nixos-infect.git)
       - in-place install nixOS to cloud instances with other linuxes
       - do not handle secure boot

### 2. procedure: ###

#### 2.1 install ubuntu using same partition scheme as nixOS ####

##### note: the following partition names are different per situation

+ partition table (optional, for empty disk)
```
  parted /dev/sda -- mklabel gpt 
```
+ efi - /dev/sda1
```
  parted /dev/sda -- mkpart ESP fat32 1MiB 512MiB
  parted /dev/sda -- set 1 esp on
```
+ root - /dev/sda2
```
  parted /dev/sda -- mkpart primary 512MiB -12GiB
```
+ swap - /dev/sda3:
```
  parted /dev/sda -- mkpart primary linux-swap -12GiB 100%
```

+ formatting
```
  mkfs.ext4 -L nixos /dev/sda2
  mkswap -L swap /dev/sda3
  mkfs.fat -F 32 -n boot /dev/sda1
```
+ proceed with normal ubuntu install and ensure partitions mounts
  + EFI: /dev/sda1 -> /boot/efi
  + Root: /dev/sda2 -> /

#### 2.2 disable shim checking ####

+ reboot into ubuntu, install mokutil, disable checking
```
  sudo apt-get install mokutil
  sudo mokutil --disable-validation
```
+ then reboot, go thru mok prompts, confirm disable-validation
  
#### 2.3 install nixOS in place ####

+ ref: nixOS manual, section 2.5.4 Installing from another Linux distribution

+ rebooting into ubuntu
```
  sudo apt-get update
  sudo apt-get install curl vim efibootmgr gparted
```
+ install nix
```
  curl -L https://nixos.org/nix/install | sh
```

+ add nixOS channel and install tools
```
  nix-channel --add https://nixos.org/channels/nixos-22.05 nixos
  nix-channel --add https://nixos.org/channels/nixos-22.05 nixpkgs
  nix-channel --update
  nix-channel --list

  nix-env -f '<nixpkgs>' -iA nixos-install-tools
```
+ generate initial nixos config
```
  export LANG=C
  sudo `which nixos-generate-config` 
```
+ copy a bare minimal nixOS config with grub active, no root passwd
```
  sudo cp ./configuration.nix /etc/nixos/
```

+ manually change /etc/nixos/hardware-configuration.nix,
  remove snapd mappings, change original mapping "boot/efi"
  to "boot" (per the above discussed ubuntu,nixOS mount diff)
```
  sudo vi /etc/nixos/hardware-configuration.nix
```


+ download nixOS 
```
  nix-env -p /nix/var/nix/profiles/system -f '<nixpkgs/nixos>' -I nixos-config=/etc/nixos/configuration.nix -iA system
  sudo chown -R 0:0 /nix
```
+ setup for in-place install
```
  sudo touch /etc/NIXOS
  sudo touch /etc/NIXOS_LUSTRATE
  echo etc/nixos | sudo tee -a /etc/NIXOS_LUSTRATE
```
+ setup boot, move EFI partition from /boot/EFI to /boot
```
  sudo umount /dev/sda1 (/boot/efi)
  sudo mv -v /boot /boot.bak  #backup, to be removed
  sudo mkdir -p /boot
  sudo mount /dev/sda1 /boot
  sudo cp -fr /boot /boot.bak2  #backup, to be removed
  sudo find /boot
```
+ install nixOS boot
```
  export LANG=C
  sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
  sudo find /boot
```
  verify /boot/EFI/NixOS-boot/grubx64.efi installed

+ now copy grub-shim related files from ubuntu/ into NixOS-boot/
```
  cd /boot/EFI/ubuntu
  sudo cp BOOTX64.CSV grub.cfg mmx64.efi shimx64.efi ../NixOS-boot/
```
+ setup efi boot menu
  check current efi, find old nixos boot entry num
```
  sudo efibootmgr -v
```
+ delete old entry for nixOS which points to nixos image
```
  sudo efibootmgr --bootnum old-nixos-entry-num(eg 0001) --delete-bootnum
```
+ add entry to boot to shim for nixos
```
  ls /boot/efi/NixOS-boot/
  sudo efibootmgr --create --label "NixOS-boot-shim" --loader "\EFI\NixOS-boot\shimx64.efi"
```
+ verify nixos-boot is 1st in boot order, otherwise change order
```
  sudo efibootmgr -v
```

+ if things are fine, reboot
```
  sudo reboot
```

#### 2.4 after reboot into nixOS ####

2.4.1 login root, set passwd
```
  sudo passwd root
  sudo passwd loc1
```
+ update nix-channel before any nixos-rebuild
```
  nix-channel --update
```
+ if things are fine, cleanup
```
  rm -fr /old-root /boot.bak*
```

2.4.2 login as user-with-sudo
+ update /etc/nixos/configuration.nix to include X11, Window-Manager, etc.,
+ rebuild nixos
```
  sudo nixos-rebuild switch
```
