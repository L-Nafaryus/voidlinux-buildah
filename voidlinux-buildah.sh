#!/usr/bin/env bash

BUILD=musl
TYPE=standart

while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        --musl)
            BUILD=musl
            shift
            ;;

        --glibc)
            BUILD=glibc
            shift
            ;;

        --standart)
            TYPE=standart
            shift
            ;;

        --minimal)
            TYPE=minimal
            shift
            ;;

        -h|--help)
            _help
            exit 0
            ;;
    esac
done

cleanup()
{
    ((${#alpine})) && buildah rm $alpine
    ((${#voidlinux})) && buildah rm $voidlinux
}

trap cleanup EXIT
set -ex

#AUTHOR=""
REPO="https://alpha.de.repo.voidlinux.org"
XBPS_ARCH="x86_64"
CURRENT="${REPO}/current/musl"
NAME="voidlinux-$BUILD"
TAG="latest"

[ $TYPE != "standart" ] && NAME="$NAME-$TYPE"

TARGET="/void"

###
#   alpine
##
alpine=$( buildah from --name "voidlinux-build" alpine )
alpine_mount=$( buildah mount $alpine )

buildah run $alpine -- apk add wget ca-certificates bash 

wget -q -O- "${REPO}/static/xbps-static-latest.${XBPS_ARCH}-musl.tar.xz" | tar xJ -C $alpine_mount

buildah run $alpine -- bash -e <<- EOF
    mkdir -p $TARGET/var/db/xbps
    cp -r /var/db/xbps/keys/ $TARGET/var/db/xbps/

    xbps-install -Sy  -R ${CURRENT} -r $TARGET base-files xbps busybox-huge ca-certificates bash

    for i in \$(chroot $TARGET busybox | tail -n+\$(expr 1 + \$(chroot void busybox | grep -n "^Currently" | cut -d: -f1)) | sed "s/,//g" | xargs echo)
    do
	    ln -svf /usr/bin/busybox $TARGET/usr/bin/\$i
    done

    mkdir $TARGET/etc/ssl/certs && chroot $TARGET update-ca-certificates --fresh
    chroot $TARGET xbps-reconfigure -a

    chroot $TARGET sh -c 'xbps-rindex -c /var/db/xbps/htt*'
EOF

###
#   voidlinux
##
voidlinux=$( buildah from --name "voidlinux" scratch )
voidlinux_mount=$( buildah mount $voidlinux )

buildah config --env XBPS_ARCH=$XBPS_ARCH $voidlinux
buildah config --cmd /bin/sh $voidlinux
buildah config --label name="$NAME" $voidlinux

buildah copy $voidlinux "$alpine_mount$TARGET" /

[ $TYPE == "minimal" ] && buildah run $voidlinux -- xbps-install -Sy base-minimal

[ $BUILD == "glibc" ] && buildah run $voidlinux -- bash -e <<- EOF
    xbps-install -Sy glibc-locales
    sed -i 's/^#en_US/en_US/' /target/etc/default/libc-locales
    xbps-reconfigure -a
EOF

buildah run $voidlinux -- bash -e <<- EOF
    xbps-remove -y bash

    rm -rf /var/cache/xbps 
    rm -rf /usr/share/man/*
    rm -rf /usr/lib/gconv/[BCDEFGHIJKLMNOPQRSTVZYZ]*
    rm -rf /usr/lib/gconv/lib*
EOF

buildah commit --squash $voidlinux "$NAME:$TAG"

buildah unmount $alpine_mount
