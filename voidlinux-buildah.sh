#!/usr/bin/env bash

_help()
{
    cat <<- EOF
Usage:
    $(basename "$0") [options ...]
    
Options:
    --musl|--glibc          Set a libc implementation (default: --musl).
    --standart|--minimal    Set a type which determines additional packages (default: --standart).
EOF
}

_parseargs()
{
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

            --debug)
                DEBUG=true
                shift
                ;;

            -h|--help)
                _help
                exit 0
                ;;

            *)
                _help
                exit 1
                ;;
        esac
    done
}

cleanup()
{
    ((${#alpine})) && buildah rm $alpine
    ((${#voidlinux})) && buildah rm $voidlinux
}

###
#   Main entry
##
trap cleanup INT TERM EXIT

BUILD=musl
TYPE=standart

_parseargs "$@"

((${#DEBUG})) && set -x 

#AUTHOR=""
REPO="https://alpha.de.repo.voidlinux.org"
ARCH="x86_64"
XBPS_ARCH="x86_64-musl"
CURRENT="${REPO}/current/musl"
NAME="voidlinux-$BUILD"
TAG="latest"

[ $BUILD == "glibc" ] && XBPS_ARCH="x86_64" && CURRENT="$REPO/current"
[ $TYPE != "standart" ] && NAME="$NAME-$TYPE"

TARGET="/void"

###
#   alpine
##
alpine=$( buildah from --name "voidlinux-build" alpine )
alpine_mount=$( buildah mount $alpine )

buildah run $alpine -- apk add wget ca-certificates bash 

wget -q -O- "${REPO}/static/xbps-static-latest.${ARCH}-musl.tar.xz" | tar xJ -C $alpine_mount

buildah run $alpine -- bash -e <<- EOF
    export XBPS_ARCH=${XBPS_ARCH}

    mkdir -p $TARGET/var/db/xbps
    cp -r /var/db/xbps/keys/ $TARGET/var/db/xbps/

    xbps-install -Sy  -R ${CURRENT} -r $TARGET base-files xbps busybox-huge ca-certificates bash

    for i in \$(chroot $TARGET busybox | tail -n+\$(expr 1 + \$(chroot void busybox | grep -n "^Currently" | cut -d: -f1)) | sed "s/,//g" | xargs echo)
    do
	    ln -sf /usr/bin/busybox $TARGET/usr/bin/\$i
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
    sed -i 's/^#en_US/en_US/' /etc/default/libc-locales
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

