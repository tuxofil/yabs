#!/bin/sh

## ---------------------------------------------
## definitions

# where packages will be published
REPO=/srv/www/htdocs/

# work directory
RUNDIR=/var/lib/yabs

# SRPM packages queue directory
INCOMING_DIR="$RUNDIR"/incoming

# where build logs will be stored
LOGS_DIR="$RUNDIR"/logs

# where failed SRPMs will be moved
FAIL_DIR="$RUNDIR"/fail

## ---------------------------------------------
## internal declarations

# lock file
LOCK_FILE="lock"

# yabs builder script location
YABS="/usr/sbin/yabs"

# where the packages will build
ROOTFS="$RUNDIR"/rootfs

# filename with list of used package repositories
REPO_LIST="/etc/yabs/repo.list"

## ---------------------------------------------
## functions

do_build(){
    local SRPM="$1"
    LOGFILE="$LOGS_DIR"/`basename "$SRPM"`.log
    date > "$LOGFILE"
    "$YABS" "$SRPM" "$ROOTFS" "$REPO" "$REPO_LIST" >> "$LOGFILE" 2>&1
    RET=$?
    date >> "$LOGFILE"
    return $RET
}

## ---------------------------------------------
## main

mkdir --parents "$RUNDIR"
cd "$RUNDIR"

# do not allow more than one simultaneous processes
exec 3>lock
flock --nonblock --exclusive 3 || exit 1

set -e
mkdir --parents "$INCOMING_DIR" "$LOGS_DIR" "$FAIL_DIR"
set +e

SUCCESS="false"
for SRPM in "$INCOMING_DIR"/*.src.rpm; do
    [ -f "$SRPM" ] || continue
    if do_build "$SRPM"; then
	SUCCESS="true"
	rm --force "$SRPM"
    else
	mv --force "$SRPM" "$FAIL_DIR"
    fi
done

if [ "$SUCCESS" = "true" ]; then
    # update repo meta info if at least one
    # package where built successfull
    cd "$REPO"/RPMS
    createrepo --update --quiet .
fi

