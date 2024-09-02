#!/bin/bash

# Set keyboard layout
loadkeys uk

# Partition the disk
echo -e "o\nn\np\n1\n\n+1G\nt\n83\nn\np\n2\n\n+50G\nn\np\n3\n\n\nw" | fdisk /dev/sda

# Format the partitions
mkfs.ext4 /dev/sda1
mkfs.ext4 /dev/sda2
mkfs.ext4 /dev/sda3

# Mount the file systems
mkdir -p /mnt/boot /mnt/home
mount /dev/sda2 /mnt
mount /dev/sda1 /mnt/boot
mount /dev/sda3 /mnt/home

# Connect to WiFi
iwctl << EOF
station wlan0 scan
station wlan0 connect TALKTALKD6C34B
exit
EOF

ping -c 3 google.com

# Install base system
pacman -Sy
pacman -S reflector
reflector --country 'United Kingdom' --latest 5 --sort rate --save /etc/pacman.d/mirrorlist
pacstrap /mnt base linux linux-firmware vim nano

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Change root into the new system
arch-chroot /mnt << EOF

# Set time zone
ln -sf /usr/share/zoneinfo/Europe/London /etc/localtime
hwclock --systohc --localtime

# Locale settings
sed -i 's/#en_GB.UTF-8 UTF-8/en_GB.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf
export LANG=en_GB.UTF-8

# Set hostname and hosts
echo "arch" > /etc/hostname
cat << HOSTS > /etc/hosts
127.0.0.1	localhost
::1		localhost
127.0.1.1	arch.localdomain	arch
HOSTS

# Set root password
echo -e "okayloka\nokayloka" | passwd

# Install and configure GRUB
pacman -S grub --noconfirm
grub-install --target=i386-pc /dev/sda
grub-mkconfig -o /boot/grub/grub.cfg

# Create a new user and configure sudo
pacman -S sudo --noconfirm
useradd -m loka
echo -e "okayloka\nokayloka" | passwd loka
usermod -aG wheel,audio,video,storage loka
sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# Install essential packages and enable services
pacman -Syy
pacman -S xfce4 xfce4-goodies iwd git alsa-utils pulseaudio wget curl bash-completion unzip vim nano openssh base-devel networkmanager lightdm lightdm-gtk-greeter xorg --noconfirm
systemctl enable NetworkManager
systemctl enable lightdm

# Set up WiFi
ip link set wlan0 up
wpa_passphrase TALKTALKD6C34B UXD38DQ3 > /etc/wpa_supplicant/wpa_supplicant.conf
echo -e "nameserver 8.8.8.8\nnameserver 8.8.4.4" > /etc/resolv.conf
wpa_supplicant -B -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf
dhcpcd wlan0

EOF

# Unmount partitions and reboot
umount -l /mnt
reboot
