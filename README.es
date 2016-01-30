# Multistrap image creator


Bienvenido al creador de imagenes para distribuciones basadas en debian.

USO:

   ./build.sh --arch=$arch --dist=$dist --size=$size --pkgs="$pkg1 $pkg2 $pkgn"

       --arch      Arquitectura a usar, se soportan: amd64, i386, armhf
       --dist      Distribución a usar, se soportan: debian, ubuntu
       --size      Tamaño de la imagen RAW resultante
       --pkgs      Paquetes extras a instalar

   ATENCIÓN: No es posible crear imagenes amd64 en un equipo de i386 y no todas las
             arquitecturas son soportadas por todas las distribuciones, ejecuta ./build.sh
             para ver las conbinaciones soportadas

