#!/bin/sh
#
# builder_defaults.sh
#
# Copyright (c) 2004-2015 Electric Sheep Fencing, LLC. All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in
#    the documentation and/or other materials provided with the
#    distribution.
#
# 3. All advertising materials mentioning features or use of this software
#    must display the following acknowledgment:
#    "This product includes software developed by the pfSense Project
#    for use in the pfSense® software distribution. (http://www.pfsense.org/).
#
# 4. The names "pfSense" and "pfSense Project" must not be used to
#    endorse or promote products derived from this software without
#    prior written permission. For written permission, please contact
#    coreteam@pfsense.org.
#
# 5. Products derived from this software may not be called "pfSense"
#    nor may "pfSense" appear in their names without prior written
#    permission of the Electric Sheep Fencing, LLC.
#
# 6. Redistributions of any form whatsoever must retain the following
#    acknowledgment:
#
# "This product includes software developed by the pfSense Project
# for use in the pfSense software distribution (http://www.pfsense.org/).
#
# THIS SOFTWARE IS PROVIDED BY THE pfSense PROJECT ``AS IS'' AND ANY
# EXPRESSED OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE pfSense PROJECT OR
# ITS CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
# NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED
# OF THE POSSIBILITY OF SUCH DAMAGE.
#

###########################################
# Product builder configuration file      #
# Please don't modify this file, you      #
# can put your settings and options       #
# in build.conf, which is sourced at the  #
# beginning of this file                  #
###########################################

if [ -z "${BUILDER_ROOT}" ]; then
	echo ">>> ERROR: BUILDER_ROOT must be defined by script that includes builder_defaults.sh"
	exit 1
fi

if [ ! -d "${BUILDER_ROOT}" ]; then
	echo ">>> ERROR: BUILDER_ROOT is invalid"
	exit 1
fi

export BUILDER_TOOLS=${BUILDER_TOOLS:-"${BUILDER_ROOT}/tools"}

if [ ! -d "${BUILDER_TOOLS}" ]; then
	echo ">>> ERROR: BUILDER_TOOLS is invalid"
	exit 1
fi

BUILD_CONF="${BUILDER_ROOT}/build.conf"

# Ensure file exists
if [ -f ${BUILD_CONF} ]; then
	. ${BUILD_CONF}
fi

# Make sure pkg will not be interactive
export ASSUME_ALWAYS_YES=true

# Architecture, supported ARCH values are:
#  Tier 1: i386, AMD64, and PC98
#  Tier 2: ARM, PowerPC, ia64, Sparc64 and sun4v
#  Tier 3: MIPS and S/390
#  Tier 4: None at the moment
#  Source: http://www.freebsd.org/doc/en/articles/committers-guide/archs.html
export TARGET=${TARGET:-"`uname -m`"}
export TARGET_ARCH=${TARGET_ARCH:-${TARGET}}
# Set TARGET_ARCH_CONF_DIR
if [ "$TARGET_ARCH" = "" ]; then
        export TARGET_ARCH=`uname -p`
fi

# Directory to be used for writing temporary information
export SCRATCHDIR=${SCRATCHDIR:-"${BUILDER_ROOT}/tmp"}
if [ ! -d ${SCRATCHDIR} ]; then
	mkdir -p ${SCRATCHDIR}
fi

# Product details
export PRODUCT_NAME=${PRODUCT_NAME:-"nonSense"}
export PRODUCT_NAME_SUFFIX=${PRODUCT_NAME_SUFFIX:-"-CE"}
export PRODUCT_URL=${PRODUCT_URL:-""}
export PRODUCT_SRC=${PRODUCT_SRC:-"${BUILDER_ROOT}/src"}
export PRODUCT_EMAIL=${PRODUCT_EMAIL:-"coreteam@pfsense.org"}
export XML_ROOTOBJ=${XML_ROOTOBJ:-$(echo "${PRODUCT_NAME}" | tr '[[:upper:]]' '[[:lower:]]')}

if [ "${PRODUCT_NAME}" = "pfSense" -a "${BUILD_AUTHORIZED_BY_ELECTRIC_SHEEP_FENCING}" != "yes" ]; then
	echo ">>>ERROR: According the following license, only Electric Sheep Fencing can build genuine pfSense® software"
	echo ""
	cat ${BUILDER_ROOT}/license.txt
	exit 1
fi

if [ -z "${PRODUCT_VERSION}" ]; then
	if [ ! -f ${PRODUCT_SRC}/etc/version ]; then
		echo ">>> ERROR: PRODUCT_VERSION is not defined and ${PRODUCT_SRC}/etc/version was not found"
		print_error_pfS
	fi

	export PRODUCT_VERSION=$(head -n 1 ${PRODUCT_SRC}/etc/version)
fi
export PRODUCT_REVISION=${PRODUCT_REVISION:-""}

# Product repository tag to build
_cur_git_repo_branch_or_tag=$(git -C ${BUILDER_ROOT} rev-parse --abbrev-ref HEAD)
if [ "${_cur_git_repo_branch_or_tag}" = "HEAD" ]; then
	# We are on a tag, lets find out its name
	export GIT_REPO_BRANCH_OR_TAG=$(git -C ${BUILDER_ROOT} describe --tags)
else
	export GIT_REPO_BRANCH_OR_TAG="${_cur_git_repo_branch_or_tag}"
fi
# Use vX_Y instead of RELENG_X_Y for poudriere to make it shorter
POUDRIERE_BRANCH=$(echo "${GIT_REPO_BRANCH_OR_TAG}" | sed 's,RELENG_,v,')

GIT_REPO_BASE=$(git -C ${BUILDER_ROOT} config --get remote.origin.url | sed -e 's,/[^/]*$,,')

# This is used for using svn for retrieving src
export FREEBSD_REPO_BASE=${FREEBSD_REPO_BASE:-"${GIT_REPO_BASE}/freebsd-src.git"}
export FREEBSD_BRANCH=${FREEBSD_BRANCH:-"devel"}
export FREEBSD_SRC_DIR=${FREEBSD_SRC_DIR:-"${SCRATCHDIR}/FreeBSD-src"}

export BUILD_KERNELS=${BUILD_KERNELS:-"${PRODUCT_NAME}"}

# XXX: Poudriere doesn't like ssh short form
case "${FREEBSD_REPO_BASE}" in
	git@*)
		export FREEBSD_REPO_BASE_POUDRIERE="ssh://$(echo ${FREEBSD_REPO_BASE} | sed 's,:,/,')"
		;;
	*)
		export FREEBSD_REPO_BASE_POUDRIERE="${FREEBSD_REPO_BASE}"
		;;
esac

# Leave this alone.
export SRC_CONF=${SRC_CONF:-"${FREEBSD_SRC_DIR}/release/conf/${PRODUCT_NAME}_src.conf"}
export MAKE_CONF=${MAKE_CONF:-"${FREEBSD_SRC_DIR}/release/conf/${PRODUCT_NAME}_make.conf"}

# Extra tools to be added to ITOOLS
export EXTRA_TOOLS=${EXTRA_TOOLS:-"uuencode uudecode ex"}

# Path to kernel files being built
export KERNEL_BUILD_PATH=${KERNEL_BUILD_PATH:-"${SCRATCHDIR}/kernels"}

# Do not touch builder /usr/obj
export MAKEOBJDIRPREFIX=${MAKEOBJDIRPREFIX:-"${SCRATCHDIR}/obj"}

# Controls how many concurrent make processes are run for each stage
_CPUS=""
if [ -z "${NO_MAKEJ}" ]; then
	_CPUS=$(expr $(sysctl -n kern.smp.cpus) '*' 2)
	if [ -n "${_CPUS}" ]; then
		_CPUS="-j${_CPUS}"
	fi
fi

export MAKEJ_WORLD=${MAKEJ_WORLD:-"${_CPUS}"}
export MAKEJ_KERNEL=${MAKEJ_KERNEL:-"${_CPUS}"}

export MODULES_OVERRIDE=${MODULES_OVERRIDE:-"i2c ipmi ndis ipfw ipdivert dummynet fdescfs opensolaris zfs glxsb if_stf coretemp amdtemp aesni sfxge hwpmc vmm nmdm ix ixv"}

# Area that the final image will appear in
export IMAGES_FINAL_DIR=${IMAGES_FINAL_DIR:-"${SCRATCHDIR}/${PRODUCT_NAME}/"}

export BUILDER_LOGS=${BUILDER_LOGS:-"${BUILDER_ROOT}/logs"}
if [ ! -d ${BUILDER_LOGS} ]; then
	mkdir -p ${BUILDER_LOGS}
fi

# This is where files will be staged
export STAGE_CHROOT_DIR=${STAGE_CHROOT_DIR:-"${SCRATCHDIR}/stage-dir"}

# Directory that will clone to in order to create
# iso staging area.
export FINAL_CHROOT_DIR=${FINAL_CHROOT_DIR:-"${SCRATCHDIR}/final-dir"}

# OVF/vmdk parms
# Name of ovf file included inside OVA archive
export OVFTEMPLATE=${OVFTEMPLATE:-"${BUILDER_TOOLS}/templates/ovf/${PRODUCT_NAME}.ovf"}
# / partition to be used by mkimg
export OVFUFS=${OVFUFS:-"${PRODUCT_NAME}${PRODUCT_NAME_SUFFIX}-disk1.ufs"}
# Raw disk to be converted to vmdk
export OVFRAW=${OVFRAW:-"${PRODUCT_NAME}${PRODUCT_NAME_SUFFIX}-disk1.raw"}
# On disk name of VMDK file included in OVA
export OVFVMDK=${OVFVMDK:-"${PRODUCT_NAME}${PRODUCT_NAME_SUFFIX}-disk1.vmdk"}
# 8 gigabyte on disk VMDK size
export VMDK_DISK_CAPACITY_IN_GB=${VMDK_DISK_CAPACITY_IN_GB:-"8"}
# swap partition size (freebsd-swap)
export OVA_SWAP_PART_SIZE_IN_GB=${OVA_SWAP_PART_SIZE_IN_GB:-"0"}
# Temporary place to save files
export OVA_TMP=${OVA_TMP:-"${SCRATCHDIR}/ova_tmp"}
# end of OVF

# Number of code images on media (1 or 2)
export NANO_IMAGES=2
# 0 -> Leave second image all zeroes so it compresses better.
# 1 -> Initialize second image with a copy of the first
export NANO_INIT_IMG2=1
export NANO_NEWFS="-b 4096 -f 512 -i 8192 -O1"
export FLASH_SIZE=${FLASH_SIZE:-"2g"}
# Size of code file system in 512 bytes sectors
# If zero, size will be as large as possible.
export NANO_CODESIZE=0
# Size of data file system in 512 bytes sectors
# If zero: no partition configured.
# If negative: max size possible
export NANO_DATASIZE=0
# Size of Product /conf partition  # 102400 = 50 megabytes.
export NANO_CONFSIZE=102400
# packet is OK for 90% of embedded
export NANO_BOOT0CFG="-o packet -s 1 -m 3"

# NOTE: Date string is used for creating file names of images
#       The file is used for sharing the same value with build_snapshots.sh
export DATESTRINGFILE=${DATESTRINGFILE:-"$SCRATCHDIR/version.snapshots"}
if [ -z "${DATESTRING}" ]; then
	if [ -f "${DATESTRINGFILE}" -a -n "${_USE_OLD_DATESTRING}" ]; then
		export DATESTRING=$(cat $DATESTRINGFILE)
	else
		export DATESTRING=$(date "+%Y%m%d-%H%M")
	fi
fi
echo "$DATESTRING" > $DATESTRINGFILE

# NOTE: Date string is placed on the final image etc folder to help detect new updates
#       The file is used for sharing the same value with build_snapshots.sh
export BUILTDATESTRINGFILE=${BUILTDATESTRINGFILE:-"$SCRATCHDIR/version.buildtime"}
if [ -z "${BUILTDATESTRING}" ]; then
	if [ -f "${BUILTDATESTRINGFILE}" -a -n "${_USE_OLD_DATESTRING}" ]; then
		export BUILTDATESTRING=$(cat $BUILTDATESTRINGFILE)
	else
		export BUILTDATESTRING=$(date "+%a %b %d %T %Z %Y")
	fi
fi
echo "$BUILTDATESTRING" > $BUILTDATESTRINGFILE

STAGING_HOSTNAME=${STAGING_HOSTNAME:-"release-staging.netgate.com"}

# Poudriere
export ZFS_TANK=${ZFS_TANK:-"zroot"}
export ZFS_ROOT=${ZFS_ROOT:-"/poudriere"}

export POUDRIERE_BULK=${POUDRIERE_BULK:-"${BUILDER_TOOLS}/conf/pfPorts/poudriere_bulk"}
export POUDRIERE_PORTS_GIT_URL=${POUDRIERE_PORTS_GIT_URL:-"${GIT_REPO_BASE}/freebsd-ports.git"}
export POUDRIERE_PORTS_GIT_BRANCH=${POUDRIERE_PORTS_GIT_BRANCH:-"devel"}

# Use vX_Y instead of RELENG_X_Y for poudriere to make it shorter
POUDRIERE_PORTS_BRANCH=$(echo "${POUDRIERE_PORTS_GIT_BRANCH}" | sed 's,RELENG_,v,')

export POUDRIERE_PORTS_NAME=${POUDRIERE_PORTS_NAME:-"${PRODUCT_NAME}_${POUDRIERE_PORTS_BRANCH}"}

# XXX: Poudriere doesn't like ssh short form
case "${POUDRIERE_PORTS_GIT_URL}" in
	git@*)
		POUDRIERE_PORTS_GIT_URL="ssh://$(echo ${POUDRIERE_PORTS_GIT_URL} | sed 's,:,/,')"
		;;
esac

unset _IS_RELEASE
unset CORE_PKG_DATESTRING
export TIMESTAMP_SUFFIX="-${DATESTRING}"
# pkg doesn't like - as version separator, use . instead
export PKG_DATESTRING=$(echo "${DATESTRING}" | sed 's,-,.,g')
case "${PRODUCT_VERSION##*-}" in
	RELEASE)
		export _IS_RELEASE=yes
		unset TIMESTAMP_SUFFIX
		;;
	ALPHA|DEVELOPMENT)
		export CORE_PKG_DATESTRING=".a.${PKG_DATESTRING}"
		;;
	BETA*)
		export CORE_PKG_DATESTRING=".b.${PKG_DATESTRING}"
		;;
	RC*)
		export CORE_PKG_DATESTRING=".r.${PKG_DATESTRING}"
		;;
	*)
		echo ">>> ERROR: Invalid PRODUCT_VERSION format ${PRODUCT_VERSION}"
		exit 1
esac

# Host to rsync pkg repos from poudriere
export PKG_RSYNC_HOSTNAME=${PKG_RSYNC_HOSTNAME:-${STAGING_HOSTNAME}}
export PKG_RSYNC_USERNAME=${PKG_RSYNC_USERNAME:-"wwwsync"}
export PKG_RSYNC_SSH_PORT=${PKG_RSYNC_SSH_PORT:-"22"}
export PKG_RSYNC_DESTDIR=${PKG_RSYNC_DESTDIR:-"/staging/ce/packages"}
export PKG_RSYNC_LOGS=${PKG_RSYNC_LOGS:-"/staging/ce/packages/logs/${POUDRIERE_BRANCH}/${TARGET}"}

# Final packages server
if [ -n "${_IS_RELEASE}" ]; then
	export PKG_FINAL_RSYNC_HOSTNAME=${PKG_FINAL_RSYNC_HOSTNAME:-"pkg.pfsense.org"}
	export PKG_FINAL_RSYNC_DESTDIR=${PKG_FINAL_RSYNC_DESTDIR:-"/usr/local/www/pkg"}
else
	export PKG_FINAL_RSYNC_HOSTNAME=${PKG_FINAL_RSYNC_HOSTNAME:-"beta.pfsense.org"}
	export PKG_FINAL_RSYNC_DESTDIR=${PKG_FINAL_RSYNC_DESTDIR:-"/usr/local/www/beta/packages"}
fi
export PKG_FINAL_RSYNC_USERNAME=${PKG_FINAL_RSYNC_USERNAME:-"wwwsync"}
export PKG_FINAL_RSYNC_SSH_PORT=${PKG_FINAL_RSYNC_SSH_PORT:-"22"}
export SKIP_FINAL_RSYNC=${SKIP_FINAL_RSYNC:-}

# pkg repo variables
export USE_PKG_REPO_STAGING="1"
export PKG_REPO_SERVER_DEVEL=${PKG_REPO_SERVER_DEVEL:-"pkg+https://beta.pfsense.org/packages"}
export PKG_REPO_SERVER_RELEASE=${PKG_REPO_SERVER_RELEASE:-"pkg+https://beta.pfsense.org/packages"}
export PKG_REPO_SERVER_STAGING=${PKG_REPO_SERVER_STAGING:-"pkg+http://${STAGING_HOSTNAME}/ce/packages"}

if [ -n "${_IS_RELEASE}" ]; then
	export PKG_REPO_BRANCH_RELEASE=${PKG_REPO_BRANCH_RELEASE:-${POUDRIERE_BRANCH}}
	export PKG_REPO_BRANCH_DEVEL=${PKG_REPO_BRANCH_DEVEL:-${POUDRIERE_BRANCH}}
	export PKG_REPO_BRANCH_STAGING=${PKG_REPO_BRANCH_STAGING:-${PKG_REPO_BRANCH_RELEASE}}
else
	export PKG_REPO_BRANCH_RELEASE=${PKG_REPO_BRANCH_RELEASE:-${POUDRIERE_BRANCH}}
	export PKG_REPO_BRANCH_DEVEL=${PKG_REPO_BRANCH_DEVEL:-${POUDRIERE_BRANCH}}
	export PKG_REPO_BRANCH_STAGING=${PKG_REPO_BRANCH_STAGING:-${PKG_REPO_BRANCH_DEVEL}}
fi

if [ -n "${_IS_RELEASE}" ]; then
	export PKG_REPO_SIGN_KEY=${PKG_REPO_SIGN_KEY:-"release${PRODUCT_NAME_SUFFIX}"}
else
	export PKG_REPO_SIGN_KEY=${PKG_REPO_SIGN_KEY:-"beta${PRODUCT_NAME_SUFFIX}"}
fi
# Command used to sign pkg repo
export PKG_REPO_SIGNING_COMMAND=${PKG_REPO_SIGNING_COMMAND:-"ssh sign@codesigner.netgate.com sudo ./sign.sh ${PKG_REPO_SIGN_KEY}"}

# Define base package version, based on date for snaps
export CORE_PKG_VERSION="${PRODUCT_VERSION%%-*}${CORE_PKG_DATESTRING}${PRODUCT_REVISION:+_}${PRODUCT_REVISION}"
export CORE_PKG_PATH=${CORE_PKG_PATH:-"${SCRATCHDIR}/${PRODUCT_NAME}_${POUDRIERE_BRANCH}_${TARGET_ARCH}-core"}
export CORE_PKG_REAL_PATH="${CORE_PKG_PATH}/.real_${DATESTRING}"
export CORE_PKG_TMP=${CORE_PKG_TMP:-"${SCRATCHDIR}/core_pkg_tmp"}

export PKG_REPO_BASE=${PKG_REPO_BASE:-"${FREEBSD_SRC_DIR}/release/pkg_repos"}
export PKG_REPO_DEFAULT=${PKG_REPO_DEFAULT:-"${PKG_REPO_BASE}/${PRODUCT_NAME}-repo.conf"}
export PKG_REPO_PATH=${PKG_REPO_PATH:-"/usr/local/etc/pkg/repos/${PRODUCT_NAME}.conf"}

export PRODUCT_SHARE_DIR=${PRODUCT_SHARE_DIR:-"/usr/local/share/${PRODUCT_NAME}"}

# Package overlay. This gives people a chance to build product
# installable image that already contains certain extra packages.
#
# Needs to contain comma separated package names. Of course
# package names must be valid. Using non existent
# package name would yield an error.
#
#export custom_package_list=""

# General builder output filenames
export ISOPATH=${ISOPATH:-"${IMAGES_FINAL_DIR}/installer/${PRODUCT_NAME}${PRODUCT_NAME_SUFFIX}-${PRODUCT_VERSION}-${TARGET}${TIMESTAMP_SUFFIX}.iso"}
export MEMSTICKPATH=${MEMSTICKPATH:-"${IMAGES_FINAL_DIR}/installer/${PRODUCT_NAME}${PRODUCT_NAME_SUFFIX}-memstick-${PRODUCT_VERSION}-${TARGET}${TIMESTAMP_SUFFIX}.img"}
export MEMSTICKSERIALPATH=${MEMSTICKSERIALPATH:-"${IMAGES_FINAL_DIR}/installer/${PRODUCT_NAME}${PRODUCT_NAME_SUFFIX}-memstick-serial-${PRODUCT_VERSION}-${TARGET}${TIMESTAMP_SUFFIX}.img"}
export MEMSTICKADIPATH=${MEMSTICKADIPATH:-"${IMAGES_FINAL_DIR}/installer/${PRODUCT_NAME}${PRODUCT_NAME_SUFFIX}-memstick-ADI-${PRODUCT_VERSION}-${TARGET}${TIMESTAMP_SUFFIX}.img"}
export OVAPATH=${OVAPATH:-"${IMAGES_FINAL_DIR}/virtualization/${PRODUCT_NAME}${PRODUCT_NAME_SUFFIX}-${PRODUCT_VERSION}-${TARGET}${TIMESTAMP_SUFFIX}.ova"}

# nanobsd templates
export NANOBSD_IMG_TEMPLATE=${NANOBSD_IMG_TEMPLATE:-"${PRODUCT_NAME}${PRODUCT_NAME_SUFFIX}-${PRODUCT_VERSION}-%%SIZE%%-${TARGET}-%%TYPE%%${TIMESTAMP_SUFFIX}.img"}

# Rsync data to send snapshots
export RSYNCUSER=${RSYNCUSER:-"snapshots"}
export RSYNCPATH=${RSYNCPATH:-"/usr/local/www/snapshots/${TARGET}/${PRODUCT_NAME}_${GIT_REPO_BRANCH_OR_TAG}"}
export RSYNCLOGS=${RSYNCLOGS:-"/usr/local/www/snapshots/logs/${PRODUCT_NAME}_${GIT_REPO_BRANCH_OR_TAG}/${TARGET}"}
export RSYNCKBYTELIMIT=${RSYNCKBYTELIMIT:-"248000"}

export SNAPSHOTSLOGFILE=${SNAPSHOTSLOGFILE:-"${SCRATCHDIR}/snapshots-build.log"}
export SNAPSHOTSLASTUPDATE=${SNAPSHOTSLASTUPDATE:-"${SCRATCHDIR}/snapshots-lastupdate.log"}

if [ -n "${POUDRIERE_SNAPSHOTS}" ]; then
	export SNAPSHOTS_RSYNCIP=${PKG_RSYNC_HOSTNAME}
	export SNAPSHOTS_RSYNCUSER=${PKG_RSYNC_USERNAME}
	export SNAPSHOTS_RSYNCLOGS=${PKG_RSYNC_LOGS}
else
	export SNAPSHOTS_RSYNCIP=${RSYNCIP}
	export SNAPSHOTS_RSYNCUSER=${RSYNCUSER}
	export SNAPSHOTS_RSYNCLOGS=${RSYNCLOGS}
fi

if [ "${PRODUCT_NAME}" = "pfSense" ]; then
	export VENDOR_NAME=${VENDOR_NAME:-"Electric Sheep Fencing, LLC"}
	export OVF_INFO=${OVF_INFO:-"pfSense is a free, open source customized distribution of FreeBSD tailored for use as a firewall and router. In addition to being a powerful, flexible firewalling and routing platform, it includes a long list of related features and a package system allowing further expandability without adding bloat and potential security vulnerabilities to the base distribution. pfSense is a popular project with more than 1 million downloads since its inception, and proven in countless installations ranging from small home networks protecting a PC and an Xbox to large corporations, universities and other organizations protecting thousands of network devices."}
else
	export VENDOR_NAME=${VENDOR_NAME:-"nonSense"}
	export OVF_INFO=${OVF_INFO:-"none"}
fi
