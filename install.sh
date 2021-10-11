#!/bin/bash
set -e

download_stage3() {
  local MIRROR="https://ftp.belnet.be/pub/rsync.gentoo.org/gentoo"
  printf "\n"
  echo -e "\e[33m\xe2\x8f\xb3 Downloading the stage 3 tarball... \e[m"
  LATEST=$(wget --quiet $MIRROR/releases/amd64/autobuilds/latest-stage3-amd64.txt -O- | tail -n 1 | cut -d " " -f 1)
  echo $LATEST

  BASENAME=$(basename "$LATEST")
  wget -q --show-progress "$MIRROR/releases/amd64/autobuilds/$LATEST" 
}

MOUNT_LOCATION=/mnt/gentoo

DEVICE=/dev/vda
BOOT_PART=${DEVICE}1
SWAP_PART=${DEVICE}2
ROOT_PART=${DEVICE}3

echo "partition"

sfdisk ${DEVICE} << EOF
,256M,L,*
,4G,S
;
EOF

mkfs.ext2 ${BOOT_PART}
mkfs.ext4 ${ROOT_PART}
mkswap ${SWAP_PART}
swapon ${SWAP_PART}

echo "mount"

mount ${ROOT_PART} ${MOUNT_LOCATION}

echo "setting the date and time"

ntpd -q -g

echo "downloading the stage tarball"

cd ${MOUNT_LOCATION}
download_stage3

echo "unpacking the stage tarball"
tar xpvf stage3-*.tar.xz --xattrs-include='*.*' --numeric-owner

echo "adding make.conf"
cat << EOF > ${MOUNT_LOCATION}/etc/portage/make.conf
COMMON_FLAGS="-march=native -O2 -pipe"
CFLAGS="${COMMON_FLAGS}"
CXXFLAGS="${COMMON_FLAGS}"
MAKEOPTS="-j5"
ACCEPT_LICENSE="* -@EULA"
EOF

echo "copy dns info"
cp --dereference /etc/resolv.conf /mnt/gentoo/etc

echo "mounting the necessary filesystems"
mount --types proc /proc /mnt/gentoo/proc
mount --rbind /sys /mnt/gentoo/sys
mount --rbind /dev /mnt/gentoo/dev
mount --rbind /run /mnt/gentoo/run


echo "entering the new environment"

chroot /mnt/gentoo /bin/bash -s << EOF
#!/bin/bash

set -e 

source /etc/profile
export PS1="(chroot) ${PS1}"

mount /dev/vda1 /boot

emerge-webrsync

eselect profile set default/linux/amd64/17.1

emerge --verbose --update --deep --newuse @world

echo "Europe/Stockholm" > /etc/timezone
emerge --config sys-libs/timezone-data

cat << EOS > /etc/locale.gen
C.UTF-8 UTF-8
en_US ISO-8859-1
en_US.UTF-8 UTF-8
sv_SE ISO-8859-1
sv_SE.UTF-8 UTF-8
EOS

locale-gen

eselect locale set sv_SE.utf8

env-update && source /etc/profile && export PS1="(chroot) ${PS1}"

emerge sys-kernel/installkernel-gentoo
emerge sys-kernel/gentoo-kernel-bin

emerge sys-kernel/linux-firmware

cat << EOS > /etc/fstab 
/dev/vda1  /boot ext2  defaults,noatime  1 2
/dev/vda2  none  swap  sw              0 0
/dev/vda3  /     ext4  noatime         0 1
EOS

echo "hostname=tux" > /etc/conf.d/hostname

emerge --noreplace net-misc/netifrc

echo "config_eth0=dhcp" > /etc/conf.d/net

cd /etc/init.d
ln -s net.lo net.eth0
rc-update add net.eth0 default

passwd

emerge app-admin/sysklogd
rc-update add sysklogd default

emerge sys-process/cronie
rc-update add cronie default

emerge sys-apps/mlocate

emerge sys-fs/e2fsprogs

emerge net-misc/dhcpcd

emerge --verbose sys-boot/grub:2

grub-install /dev/vda

grub-mkconfig -o /boot/grub/grub.cfg

exit
EOF

umount -l /mnt/gentoo/dev{/shm,/pts,}
umount -R /mnt/gentoo

reboot
