#!/bin/sh

### Yet another build script.
###
### Chrooted binary RPM builder script.
### Builds binary RPM packages for OpenSuse Linux distribution
### in clean chrooted environment.
###
### Author: Aleksey Morarash <aleksey.morarash@gmail.com>
### Created: 12 Sep 2012
###

## ---------------------------------------------
## functions

error(){
    echo "$1" 1>&2
    exit 1
}

## ---------------------------------------------
## user interface section
[ `id --user` = "0" ] || \
    error "$0: must be run with superuser privileges"
SRCRPM="$1"
ROOTFS="$2"
DSTDIR="$3"
REPO_LIST="$4"
[ -z "$SRCRPM" -o -z "$ROOTFS" -o -z "$DSTDIR" -o -z "$REPO_LIST" ] && \
    error "Usage: $0 <filename.src.rpm> <rootfs.dir> <destination.repo.dir> <repo.list.file>"
[ -d "$DSTDIR" -a -w "$DSTDIR" ] || \
    error "$0: directory '$DSTDIR' is not exists or not writable"
DSTDIR=`readlink --canonicalize-existing "$DSTDIR"`
[ -f "$REPO_LIST" ] || \
    error "$0: repository list file '$REPO_LIST' is missing"
set -e
file "$1" > /dev/null
SRCRPM_BASENAME=`basename "$SRCRPM"`
mkdir --parents "$DSTDIR"/RPMS "$DSTDIR"/SRPMS
set -x

## ---------------------------------------------
## fetch build requirements...
DEPS=`rpm2cpio "$SRCRPM" | \
    cpio --extract --to-stdout '*.spec' | \
    grep --extended-regexp '^BuildRequires:' | \
    sed --regexp-extended 's/^BuildRequires:\s*//'`

## ---------------------------------------------
## initialize rootfs...
rm --recursive --force "$ROOTFS"/*
mkdir --parents "$ROOTFS"/dev
mknod --mode=666 "$ROOTFS"/dev/null c 1 3

## ---------------------------------------------
## register package repos...
for URL in `cat "$REPO_LIST"` "$DSTDIR"/RPMS; do
    zypper \
        --root "$ROOTFS" \
        --non-interactive \
        addrepo \
        --refresh \
        "$URL" "$URL"
done

## ---------------------------------------------
## install packages...
zypper \
    --root "$ROOTFS" \
    --gpg-auto-import-keys \
    --no-gpg-checks \
    --non-interactive \
    install \
    --name \
    --download-in-advance \
    --auto-agree-with-licenses \
    --no-recommends \
    -- \
    pwdutils rpm gzip tar findutils gawk \
    $DEPS

## ---------------------------------------------
## initialize users and groups...
chroot "$ROOTFS" sh -c "echo root::0:0::/root:/bin/bash > /etc/passwd"
chroot "$ROOTFS" touch /etc/group
chroot "$ROOTFS" /usr/sbin/groupadd --gid 0 root
chroot "$ROOTFS" /usr/sbin/groupadd builder
chroot "$ROOTFS" /usr/sbin/useradd --home /usr/src/packages/ --password "" --gid builder builder

## ---------------------------------------------
## deploy and build package...
cp "$SRCRPM" "$ROOTFS"/usr/src/packages/SRPMS/
chroot "$ROOTFS" chown --recursive builder:builder /usr/src/packages
chroot "$ROOTFS" su --login --command="rpmbuild --rebuild SRPMS/\"$SRCRPM_BASENAME\"" builder

## ---------------------------------------------
## deliver packages to destination directory...
RUNDIR=`pwd`
cd "$ROOTFS"/usr/src/packages/RPMS
cp --recursive --parents --force . "$DSTDIR"/RPMS/
cd "$RUNDIR"
mv "$ROOTFS"/usr/src/packages/SRPMS/"$SRCRPM_BASENAME" "$DSTDIR"/SRPMS/

## ---------------------------------------------
## clean filesystem...
rm --recursive --force "$ROOTFS"/*

set +x
echo "Success"

