#!/bin/bash
# desc: Create multistrap based debian distributions prepared to use aufs on root filesystems
#
# WARNING: You need multistrap and qemu-user-static installed in your system.
# Only root can execute the SDK, use directly or with sudo
#

# help
help() {
    echo
    echo "help for debians systems image creator for aufs root:"
    echo "USAGE:"
    echo "    $basename $0"
    echo
    echo "   --arch=\$arch       Arch to use: i386, amd64, armhf"
    echo "   --dist=\$dist       Distribution to generate: debian, raspian, ubuntu"
    echo "   --size=\$size       Size for RAW image in Gb: 1, 2, 12"
    echo "   --pkgs=\$pkgs       Extra packages to install, default basic packages are installed. This parameter is optional"
    echo "                       You can add every debian package or meta-package: gnome, kde-plasma-desktop, xfce4"
    echo; echo -n "    Posible distribution combinations: "
    for config in multistrap/*; do
        DIST=`echo $config | cut -f2 -d"/" | cut -f1 -d.`
        ARCH=`echo $config | cut -f2 -d"/" | cut -f2 -d.`
        echo -n " $DIST on $ARCH; "
    done
    echo; echo
    echo "EXAMPLE:"
    echo "    $basename $0 --arch=amd64 --dist=debian --size=12 --pkgs=\"gnome-core inkscape gimp iceweasel\""
    echo
}

# Variables, SDK Colors and visual effects
IFS=" "
MOUNTDIR="mnt"
ERRO='\e[0;31m'; INFO='\e[1;34m' ; WARN='\e[0;33m' ; OMIT='\e[1;33m'; DONE='\e[1;32m'; NORL='\e[0m'
MULTISTRAP="/usr/sbin/multistrap"
PACKAGES=`echo "$4" | cut -f2 -d=`; DEVICE=`echo "$1" | cut -f2 -d=`
RAWSIZE=`echo "$3" | cut -f2 -d=` ; DISTRO=`echo "$2" | cut -f2 -d=`
PKGSURLS="https://www.dropbox.com/s/wljr041fow6iwib/aurootfs_0.2_all.deb \
          https://www.dropbox.com/s/rqgdeewl7py513u/initramfs-tools_0.120.1_all.deb"
CHROOT="chroot"; [ "$DEVICE" != amd64 ] && test -x /usr/bin/linux32 && CHROOT="linux32 chroot"

# Check $1, $2 and $3 parameter
if test -z "$1"; then
    help
    exit 1
elif test -z "$2"; then
    help
    exit 1
elif test -z "$3"; then
    help
    exit 1
# Check multistrap config file
elif ! test -f "multistrap/$DISTRO.$DEVICE.conf"; then
    echo -e "[${ERRO} err ${NORL}] Distribution is not supported in $DEVICE, multistrap configuration file is missing"
    exit 1
# Only root can execute chroot, so root user is required
elif [ `whoami` != "root" ]; then
    echo -e "[${ERRO} err ${NORL}] You need execute by root or with sudo"
    exit 1
# In non-i386 system emulator is required to configure image
elif [ "$DEVICE" != i386 ] && ! test -x /usr/bin/qemu-arm-static; then
    echo -e "[${ERRO} err ${NORL}] You need install qemu-user-static"
    exit 1
# You are intend install amd64 in i386 system, is not posible
elif [ "$DEVICE" = amd64 ] && [ `uname -m` = i686 ]; then
    echo -e "[${ERRO} err ${NORL}] amd64 multistrap can't be created on i386 systems"
    exit 1
# Multistrap is required in host
elif ! test -x $MULTISTRAP; then
    echo -e "[${ERRO} err ${NORL}] You need install multistrap"
    exit 1
# Everything right, configure remaining variables
else
    # Delete previous files and configure new one
    rm -r $DISTRO.$DEVICE*
    LOGFILE=$DISTRO.$DEVICE.log
    CONFIG=$DISTRO.$DEVICE.conf
    TARGET=$DISTRO.$DEVICE
    cp multistrap/$CONFIG . && rm $LOGFILE &>/dev/null
    # Adding new packages to multistrap configuration file
    test -z $4 || echo "packages=$PACKAGES" >> $CONFIG
fi

configure_packages() {
    ## FIXME: Debian in RasberryPi 2 needs packages in linux-image libraspberrypi0 raspberrypi-bootloader-nokernel
    ## libraspberrypi-bin collabora-obs-archive-keyring but collabora repository use https and qemu crash with apt update
    ## Packages are added manually but repository is configured in apt sources

    # Add passwd and group file, required in arm installs
    test -f $TARGET/etc/passwd || cp $TARGET/usr/share/base-passwd/passwd.master $TARGET/etc/passwd
    test -f $TARGET/etc/group  || cp $TARGET/usr/share/base-passwd/group.master  $TARGET/etc/group
    # Installing all available emulators
    cp /usr/bin/qemu-*-static $TARGET/usr/bin
    # Configure unconfigured targets
    if [ `$CHROOT $TARGET /bin/bash -c "dpkg -s base-files | grep Status | cut -f4 -d' ' "` = "unpacked" ]; then
        $CHROOT $TARGET /bin/bash -c "LC_ALL=C LANGUAGE=C LANG=C /var/lib/dpkg/info/dash.preinst install"
        $CHROOT $TARGET /bin/bash -c "LC_ALL=C LANGUAGE=C LANG=C DEBIAN_FRONTEND=noninteractive dpkg --configure -a"
    fi
    # Installing aufs packages
    for pkgurl in "$PKGSURLS"; do
        wget --no-check-certificate --directory-prefix=$TARGET/tmp $pkgurl
    done
    $CHROOT $TARGET /bin/bash -c "LC_ALL=C LANGUAGE=C LANG=C DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/*.deb" && rm $TARGET/tmp/*
    # Umount dev filesystems, is not required anymore
    umount -fl $TARGET/dev 2>/dev/null

    # Change root password, fix adjtime file, creating fstab file and mtab symlink (prevent boot warning)
    $CHROOT $TARGET /bin/bash -c "echo -e 'root\nroot' | (passwd root)"
    touch $TARGET/etc/fstab; echo "LOCAL" > $TARGET/etc/adjtime
    test -h $TARGET/etc/mtab || ln -s /proc/mounts $TARGET/etc/mtab
    # Delete emulators
    rm -f $TARGET/usr/bin/qemu-*
}

create_image() {
    # Create, format and copy files in image
    if dd if=/dev/zero of=$TARGET.img bs=1024 count="$RAWSIZE"MB; then
       mkfs.ext2 -F $TARGET.img; mount -o loop $TARGET.img $MOUNTDIR
       cp -rp $TARGET/* $MOUNTDIR/

       # Umount image
        while ! umount $MOUNTDIR 2>/dev/null; do
            sleep 1
        done
    fi
}

# Main, build and configure image
echo
echo -e "${INFO} Welcome to Multistrap image creator SDK ${NORM}"
echo -e "${INFO} Execute tail -f logs/mkrootfs-$DEVICE.log in another terminal to see verbose process ${NORM}"
echo -e "${INFO} and don't forget configure root password (by default root) and users in new image${NORM}"
echo

# Creating folders and mounting dev, required by systemd and ssh
mkdir -p $MOUNTDIR $TARGET/dev && mount --bind /dev $TARGET/dev &>> $LOGFILE
# Creating multistrap root
echo -ne "[${INFO} 1/2 ${NORL}] Building and configure image ...                          "
if LC_ALL=C LANGUAGE=C LANG=C $MULTISTRAP -f $CONFIG &>> $LOGFILE; then
    # Multistrap only configure packages with same arch, so configure now
    if configure_packages &>> $LOGFILE; then
        # Clean lib64 directory
        [ $DEVICE != amd64 ] && rm -f $TARGET/lib64
        echo -e "(${DONE}done${NORL})"
    else
        # Umount dev device before exit
        umount -fl $TARGET/dev &>>$LOGFILE
        echo -e "(${ERRO}failed${NORL})" && exit 1
    fi
else
    # Umount dev device before exit
    umount -fl $TARGET/dev &>>$LOGFILE
    echo -e "(${ERRO}failed${NORL})" && exit 1
fi

# Creating RAW image
echo -ne "[${INFO} 2/2 ${NORL}] Creating RAW image ...                                    "
if create_image &>> $LOGFILE; then
    echo -e "(${DONE}done${NORL})"
else
    # Fail, exit now
    echo -e "(${ERRO}failed${NORL})" && exit 1
fi
