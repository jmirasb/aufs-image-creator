# Multistrap image creator

Welcome to debian based distro image creator

USE

   ./build.sh --arch=$arch --dist=$dist --size=$size --pkgs="$pkg1 $pkg2 $pkgn"
       --arch      Arch to use, supported: amd64, i386, armhf
       --dist      Linux distro to use, supported: debian, raspian and ubuntu
       --size      Final image size in GB
       --pkgs      Extra package to install in image

   WARNING: Is not possible create amd64 image with i386 based host and not all arch
            are available for all distro, execute ./build.sh to see all supported
