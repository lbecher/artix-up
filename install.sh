#!/bin/bash

gname="artix"

pefi="/dev/nvme0n1p1"
pboot="/dev/nvme0n1p2"
pluks="/dev/nvme0n1p3"

loadkeys br-abnt2

sv up ntpd

cryptsetup -s 256 -h sha256 -c aes-xts-plain64 luksFormat $pluks
cryptsetup luksOpen $pluks "${gname}_luks"

pvcreate $plvm
vgcreate $gname $plvm

lvcreate -C y -L 8GB -n swap $gname
lvcreate -C y -L 64GB -n root $gname
lvcreate -C n -l 100%FREE -n home $gname

mkswap /dev/$gname/swap

mkfs.fat -F 32 $pefi
fatlabel $pefi ESP

mkfs.xfs $pboot
mkfs.xfs /dev/$gname/root
mkfs.xfs /dev/$gname/home

mount /dev/$gname/root /mnt

mkdir /mnt/efi
mkdir /mnt/boot
mkdir /mnt/home

mount $pefi /mnt/efi
mount $pboot /mnt/boot
mount /dev/$gname/home /mnt/home

swapon /dev/$gname/swap

basestrap /mnt linux linux-firmware \
    base base-devel runit elogind-runit \
    grub os-prober efibootmgr \
    NetworkManager nano git

fstabgen -U /mnt > /mnt/etc/fstab