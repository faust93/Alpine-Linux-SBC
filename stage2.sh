#!/bin/sh

export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH

KEYBOARD_MAP="us us-intl"
TIMEZONE="UTC"
WLAN_HARDWARE_ADDR="00:E0:4C:55:61:E4"
HOSTNAME=rockpis
USER_NAME=rock
USER_PASS=rock
ROOT_PASS=rockroot

# fixing root permissions
chmod g+rx,o+rx /

# temporary adding dns server
echo -e "nameserver 1.1.1.1\nnameserver 8.8.8.8" > /etc/resolv.conf

apk update

sync && sleep 1

apk add alpine-base alpine-baselayout alpine-conf alpine-keys openrc apk-tools busybox busybox-suid chrony dbus-libs e2fsprogs e2fsprogs-libs f2fs-tools-libs f2fs-tools kbd-bkeymaps libblkid libcap libcom_err libc-utils libnl3 libressl libusb libuuid musl musl-utils network-extras openrc pcsc-lite-libs scanelf tzdata usb-modeswitch vlan sudo zlib dropbear dropbear-scp dropbear-ssh dropbear-dbclient dropbear-openrc bluez bluez-deprecated alsa-tools alsa-utils

rc-update add acpid sysinit
rc-update add crond sysinit
rc-update add devfs sysinit
rc-update add dmesg sysinit
rc-update add mdev sysinit

rc-update add bootmisc boot
rc-update add hostname boot
rc-update add hwclock boot
rc-update add networking boot
rc-update add sysctl boot
rc-update add syslog boot

rc-update add dropbear default
rc-update add chronyd default

rc-update add mount-ro shutdown
rc-update add killprocs shutdown
rc-update add savecache shutdown

# enable debug on uart
#sed -i 's/^#ttyS0/ttyS0/' /etc/inittab
echo '::respawn:/sbin/getty 38400 console' >> /etc/inittab

# debug only - disable in future
echo "ttyS0" >> /etc/securetty
echo "ttyS1" >> /etc/securetty
echo "ttyFIQ0" >> /etc/securetty

# disabling spare consoles
#sed -i 's/^tty3/#tty3/' /etc/inittab
#sed -i 's/^tty4/#tty4/' /etc/inittab
#sed -i 's/^tty5/#tty5/' /etc/inittab
#sed -i 's/^tty6/#tty6/' /etc/inittab

# this prevents lots of tty messages to be logged to syslog
sed -i 's/^tty/# tty/g' /etc/inittab

# mount boot partition
echo 'UUID=614e0000-0000-4b53-8000-1d28000054a9 /boot     ext2    defaults,noatime 0 1' >> /etc/fstab

# changing root password
echo root:$ROOT_PASS | chpasswd

# configuring keymap
setup-keymap $KEYBOARD_MAP

echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1     $HOSTNAME" >> /etc/hosts


cat << EOF > /etc/network/interfaces
auto lo
iface lo inet loopback

auto wlan0
iface wlan0 inet dhcp
  hwaddress ether $WLAN_HARDWARE_ADDR
  hostname $HOSTNAME
EOF

setup-timezone -z $TIMEZONE
#setup-apkrepos -f
setup-sshd -c dropbear
setup-ntp -c chrony

cat << EOF >> /etc/chrony/chrony.conf
initstepslew 0.5 pool.ntp.org
makestep 0.5 -1
EOF

#
# adding custom user
#
adduser -s "/bin/sh" -D $USER_NAME
echo $USER_NAME:$USER_PASS | chpasswd
chmod u+w /etc/sudoers
echo "$USER_NAME ALL=(ALL) ALL" >> /etc/sudoers
chmod u-w /etc/sudoers

exit 0
