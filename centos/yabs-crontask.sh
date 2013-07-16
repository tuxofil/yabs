#!/bin/sh

## ---------------------------------------------
## definitions

# where packages will be published
REPO=/var/www/html/yabs

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
RELEASE_PACKAGE="http://ftp.colocall.net/pub/centos/6.4/os/x86_64/Packages/centos-release-6-4.el6.centos.10.x86_64.rpm"

CURRENT_LOG="$LOGS_DIR"/current.log

## ---------------------------------------------
## functions

do_build(){
    local SRPM="$1"
    LOGFILE="$LOGS_DIR"/`basename "$SRPM"`.log
    > "$CURRENT_LOG"
    > "$LOGFILE"
    (
	date
	"$YABS" "$SRPM" "$ROOTFS" "$REPO" "$RELEASE_PACKAGE"
	RET=$?
	[ "$RET" != "0" ] && \
	    echo "FAILED with exit code $RET"
	date
	## Save task exit code in file due to
	## "cmd | tee" construction will always return
	## exit code, returned by tee, not by cmd.
	echo $RET > "$RUNDIR"/lasttaskstate
    ) 2>&1 | tee "$CURRENT_LOG" > "$LOGFILE"
    return `cat "$RUNDIR"/lasttaskstate`
}

## ---------------------------------------------
## main

mkdir --parents "$RUNDIR"
cd "$RUNDIR"

# do not allow more than one simultaneous processes
exec 3>lock
flock --nonblock --exclusive 3 || exit 1

set -e
mkdir --parents "$INCOMING_DIR" "$LOGS_DIR" "$FAIL_DIR" "$REPO"
set +e

(
    cd "$REPO"
    [ -d repodata ] || createrepo --quiet .
)

SUCCESS="false"
for SRPM in "$INCOMING_DIR"/*.src.rpm; do
    [ -f "$SRPM" ] || continue
    if do_build "$SRPM"; then
	SUCCESS="true"
	rm --force "$SRPM"
	rm --force "$FAIL_DIR"/`basename "$SRPM"`
    else
	mv --force "$SRPM" "$FAIL_DIR"
    fi
done

if [ "$SUCCESS" = "true" ]; then
    # update repo meta info if at least one
    # package where built successfull
    cd "$REPO"
    createrepo --update --quiet .
fi

