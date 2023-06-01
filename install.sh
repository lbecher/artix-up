#!/bin/bash

user="user" # nome de usuário para o usuário a ser criado

gname="system" # nome do grupo de volume LVM
hname="artix" # nome do host

pefi="/dev/nvme0n1p1"
pboot="/dev/nvme0n1p2"
pluks="/dev/nvme0n1p3"

loadkeys br-abnt2

#cryptsetup -s 256 -h sha256 -c aes-xts-plain64 luksFormat $pluks

pluks_uuid=$( blkid -o value -s UUID $pluks )
plvm="/dev/mapper/luks-${pluks_uuid}"
plvm_name="luks-${pluks_uuid}"

<<llll
cryptsetup luksOpen $pluks $plvm_name

pvcreate $plvm
vgcreate $gname $plvm

lvcreate -C y -L 8GB -n swap $gname
lvcreate -C n -L 64GB -n root $gname
lvcreate -C n -l 100%FREE -n home $gname

mkswap /dev/mapper/${gname}-swap

mkfs.fat -F 32 $pefi
fatlabel $pefi ESP

mkfs.xfs $pboot -f
mkfs.xfs /dev/mapper/${gname}-root -f
mkfs.xfs /dev/mapper/${gname}-home -f

mount /dev/mapper/${gname}-root /mnt

mkdir /mnt/efi
mkdir /mnt/boot
mkdir /mnt/home

mount $pefi /mnt/efi
mount $pboot /mnt/boot
mount /dev/mapper/${gname}-home /mnt/home

swapon /dev/mapper/${gname}-swap

basestrap /mnt linux linux-firmware \
    base base-devel runit elogind-runit \
    grub os-prober efibootmgr \
    networkmanager nano git

fstabgen -U /mnt > /mnt/etc/fstab
llll

grub_default="GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR=\"Artix\"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT=\"console\"
GRUB_CMDLINE_LINUX=\"rd.luks.uuid=${pluks_name} rhgb quiet\"
GRUB_DISABLE_RECOVERY=true
GRUB_ENABLE_BLSCFG=true
"

artix-chroot /mnt echo $grub_default > /etc/default/grub
artix-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=Artix
artix-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

mkinitcpio_conf="MODULES=()
BINARIES=()
FILES=()
HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt lvm2 filesystems fsck)
"

artix-chroot /mnt echo $mkinitcpio_conf > /etc/mkinitcpio.conf
artix-chroot /mnt mkinitcpio -P

artix-chroot /mnt echo "$hname" > /etc/hostname
artix-chroot /mnt echo -e "127.0.0.1 localhost.localdomain localhost\n::1 localhost.localdomain localhost\n127.0.1.1 $hname.localdomain $hname" > /etc/hosts
artix-chroot /mnt echo "$plvm_name UUID=$plvm_uuid none discard" > /etc/crypttab

artix-chroot /mnt echo "LANG=pt_BR.UTF-8" > /etc/locale.conf
artix-chroot /mnt echo "KEYMAP=br-abnt2" > /etc/vconsole.conf
artix-chroot /mnt echo -e "en_US.UTF-8 UTF-8\npt_BR.UTF-8 UTF-8" > /etc/locale.gen
artix-chroot /mnt locale-gen
artix-chroot /mnt ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
artix-chroot /mnt hwclock --systohc

<<userin
artix-chroot /mnt useradd -m -G wheel $user
artix-chroot /mnt passwd $user
artix-chroot /mnt EDITOR=nano visudo
userin
