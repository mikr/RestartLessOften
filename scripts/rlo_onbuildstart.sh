#!/bin/sh
#
# This script should be called at the begin of an Xcode build as first run phase after the target dependencies.
# It serves both the app build and the bundle build and decides which actions to take by looking at the PRODUCT_TYPE environment variable.
#
# Copyright (c) 2010-2013 Michael Krause ( http://krause-software.com/ ). All rights reserved.
#

set -e
set -u

if [ "$TARGET_NAME" == "$PRODUCT_NAME" ] \
    && [ "$PRODUCT_TYPE" = "com.apple.product-type.application" ] \
    && [ "$PLATFORM_NAME" = "iphoneos" ] ; then
    # This looks like a build for deployment, check for accidental misconfiguration.
    # You might want to adapt a test for a build settings for example
    # to fail the build of your app instead of shipping with RLO code.
    if [ "$GCC_SYMBOLS_PRIVATE_EXTERN" = "NO" ] ; then
        echo "This looks like a build for deployment"
        echo "GCC_SYMBOLS_PRIVATE_EXTERN (Symbols Hidden by Default) should probably be YES but is NO."
        # exit 1
    fi
fi

if [ "$DEPLOYMENT_LOCATION" = "YES" ]; then
    if [ "$TARGET_NAME" != "$PRODUCT_NAME" ]; then
        echo "TARGET_NAME=$TARGET_NAME != $PRODUCT_NAME=$PRODUCT_NAME. This should only happen for development builds."
        exit 1
    fi
	# This is an archiving build, generate an empty RLO include file
	rm -f "${BUNDLE_LOADER}"
	exit 0
fi

if [ "$PRODUCT_TYPE" = "com.apple.product-type.bundle" -o "$PRODUCT_TYPE" = "com.apple.product-type.bundle.unit-test" ]; then
	# The bundle build is starting
	if [ ! -f "${BUNDLE_LOADER}" ]; then
	    # Give this bundle a bundle loader so that the first build succeeds.
	    # After the the app is built for the first time, the bundle loader will be the app itself.
	    mkdir -p $(dirname $BUNDLE_LOADER) $DERIVED_SOURCES_DIR
	    MM="$DERIVED_SOURCES_DIR/minimalmain.c"
	    echo "int main() {}" > $MM
	    clang -arch "$CURRENT_ARCH" -isysroot $SDKROOT $MM -o "$BUNDLE_LOADER"
	fi
    CMDDIR=$(dirname $0)
    $CMDDIR/rlo_newerfiles.py -f "${BUNDLE_LOADER}" -p "${PROJECT_DIR}"

	# Record the start time of the build as a floating point number expressed in seconds since the epoch, in UTC.
	/usr/bin/python -sS -c "import time; print repr(time.time())" > ${PROJECT_TEMP_DIR}/RLObuildstart.txt
else
	# The app build is starting

	# ${TARGET_BUILD_DIR}/include is always in the HEADER_SEARCH_PATHS but this directory does not necessarily exist.
	# So we create this directory if necessary.
	INCDIR=${TARGET_BUILD_DIR}/include
	test -d $INCDIR || mkdir -p $INCDIR

    LOCALHOSTNAME="$(/bin/hostname -s).local"

    if [ $# -eq 1 ]; then
    	BUNDLENAME="$1"
    else
    	BUNDLENAME="RLOUpdaterBundle.bundle"
    fi

	cat > ${INCDIR}/env_new.h <<EOM
// Please don't modify this file, it is generated from a run script ("$0") before the application is built.

#ifndef RLODynamicEnvironment_h
#define RLODynamicEnvironment_h

#define RLO_BUNDLEUPDATE_SRCROOT @"${SRCROOT}"
#define RLO_BUNDLEUPDATE_BUNDLEPATH @"${BUILT_PRODUCTS_DIR}/${BUNDLENAME}"
#define RLO_BUNDLEUPDATE_BUNDLEEXECUTABLE @"${EXECUTABLE_PATH}"
#define RLO_BUNDLEUPDATE_TMPPATH @"${TARGET_TEMP_DIR}"
#define RLO_BUNDLEPROJECT_TMPPATH @"${PROJECT_TEMP_DIR}"
#define RLO_SERVERURL @"http://${LOCALHOSTNAME}:8080"

#endif
EOM
    # Only write the file if the content is different to reduce build time
    cmp ${INCDIR}/env_new.h ${INCDIR}/RLODynamicEnvironment.h 2>/dev/null || mv ${INCDIR}/env_new.h ${INCDIR}/RLODynamicEnvironment.h
fi
