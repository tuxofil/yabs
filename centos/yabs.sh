#!/bin/sh

### Yet another build script.
###
### Chrooted binary RPM builder script.
### Builds binary RPM packages for Centos Linux distribution
### in clean chrooted environment.
###
### Author: Aleksey Morarash <aleksey.morarash@gmail.com>
### Created: 15 Jul 2013
###

CHROOT=/usr/sbin/chroot

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
RELEASE_PACKAGE="$4"
[ -z "$SRCRPM" -o -z "$ROOTFS" -o -z "$DSTDIR" -o -z "$RELEASE_PACKAGE" ] && \
    error "Usage: $0 <filename.src.rpm> <rootfs.dir> <destination.repo.dir> <release_package_url>"
[ -d "$DSTDIR" -a -w "$DSTDIR" ] || \
    error "$0: directory '$DSTDIR' is not exists or not writable"
DSTDIR=`readlink --canonicalize-existing "$DSTDIR"`
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
mknod --mode=666 "$ROOTFS"/dev/urandom c 1 9

## ---------------------------------------------
## register package repos...
mkdir --parents "$ROOTFS"/etc/yum.repos.d
cat > "$ROOTFS"/etc/yum.repos.d/yabs.repo <<-EOF
[yabs]
name=Yabs
baseurl=http://localhost/yabs
gpgcheck=0
EOF
mkdir --parents "$ROOTFS"/var/lib/rpm
rpm --root="$ROOTFS" --rebuilddb
rpm --root="$ROOTFS" --install --nodeps "$RELEASE_PACKAGE"

## ---------------------------------------------
## install packages...
yum --installroot="$ROOTFS" --assumeyes install $DEPS \
    shadow-utils rpm-build tar

## ---------------------------------------------
## initialize users and groups...
$CHROOT "$ROOTFS" sh -c "echo root::0:0::/root:/bin/bash > /etc/passwd"
$CHROOT "$ROOTFS" touch /etc/group
$CHROOT "$ROOTFS" /usr/sbin/groupadd builder
$CHROOT "$ROOTFS" /usr/sbin/useradd --password "" --gid builder builder

## ---------------------------------------------
## deploy and build package...
mkdir --parents "$ROOTFS"/home/builder/rpmbuild/SRPMS/
cp "$SRCRPM" "$ROOTFS"/home/builder/rpmbuild/SRPMS/
$CHROOT "$ROOTFS" chown --recursive builder:builder /home/builder/rpmbuild
$CHROOT "$ROOTFS" su --login --command="rpmbuild --rebuild rpmbuild/SRPMS/\"$SRCRPM_BASENAME\"" builder

## ---------------------------------------------
## deliver packages to destination directory...
cd "$ROOTFS"/home/builder/rpmbuild
cp --recursive --parents --force RPMS/* "$DSTDIR"/
mv SRPMS/"$SRCRPM_BASENAME" "$DSTDIR"/SRPMS/

## ---------------------------------------------
## clean filesystem...
rm --recursive --force "$ROOTFS"/*

set +x
echo "Success"

