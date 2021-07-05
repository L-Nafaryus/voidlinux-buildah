#!/usr/bin/env bash

BUILD=glibc
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
    ((${#ctr})) && buildah rm $ctr
    ((${#voidlinux})) && buildah rm $voidlinux
}

trap cleanup EXIT
set -ex
REPO="https://alpha.de.repo.voidlinux.org"
XBPS_ARCH="x86_64"
[ $BUILD == "musl" ] && CURRENT="${REPO}/current/musl" || CURRENT="${REPO}/current"

ctr=$(buildah from --name "voidlinux-build" alpine)

buildah run $ctr -- apk add wget ca-certificates bash 

buildah run $ctr -- bash -e <<- EOF
    wget -q -O- "${REPO}/static/xbps-static-latest.${XBPS_ARCH}-musl.tar.xz" | tar xfJ -
    mkdir -p void/var/db/xbps
    cp -r /var/db/xbps/keys/ void/var/db/xbps/


    xbps-install -Sy  -R ${CURRENT} -r void base-files xbps busybox-huge

    busybox=$(chroot void busybox | tail -n+$(expr 1 + $(chroot void busybox | grep -n "^Currently" | cut -d: -f1)) | sed "s/,//g" | xargs echo)
    for n in $busybox; do 
        ln -s /usr/bin/busybox void/usr/bin/$n 
    done

    mkdir void/etc/ssl/certs && chroot void update-ca-certificates --fresh
    chroot void xbps-reconfigure -a

    chroot void sh -c 'xbps-rindex -c /var/db/xbps/htt*'
    rm -rf void/var/cache/xbps void/usr/share/man/*
EOF
#buildah commit $ctr voidlinux-build

voidlinux=$(buildah from --name "voidlinux" scratch)

buildah config --env XBPS_ARCH=$XBPS_ARCH $voidlinux
buildah copy --from $ctr $voidlinux /void /

[ $TYPE == "minimal" ] && buildah run $voidlinux -- xbps-install -Sy base-minimal

buildah config --cmd /bin/sh $voidlinux
buildah --label Name="voidlinux-$TYPE:$BUILD" $voidlinux

buildah commit $voidlinux

buildah rm $ctr
