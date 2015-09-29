#!/bin/sh
#
# This script should be called at the end of an Xcode build as the last run phase.
#
# Copyright (c) 2010-2013 Michael Krause ( http://krause-software.com/ ). All rights reserved.
#

set -e
set -u

if [ "$PRODUCT_TYPE" = "com.apple.product-type.bundle" -o "$PRODUCT_TYPE" = "com.apple.product-type.bundle.unit-test" ]; then
	# The bundle build is finished

	if [ "${PLATFORM_NAME}" = "iphoneos" ]; then
		# Only tell the RLO server that a new bundle exists. The server can then send the bundle to the device.

	    # code signing is not needed for the new code to run, if this ever changes, try this:
	    # codesign -f -v -s "${CODE_SIGN_IDENTITY}" "${CODESIGNING_FOLDER_PATH}"
	    BUNDLE_LOCATION="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"
	    URL="http://localhost:8080/announcebundle"
	    read RLObuildstart 2>/dev/null < ${PROJECT_TEMP_DIR}/RLObuildstart.txt
	    # Allow curl to exit with a non-zero code
	    set +e
	    /usr/bin/curl --fail --silent --data-urlencode "srcroot=${SRCROOT}" --data-urlencode "bundlelocation=${BUNDLE_LOCATION}"  --data-urlencode "rlobuildstart=${RLObuildstart}" "$URL"
	    set -e
	    true
	fi
else
	# The app build is finished
	# This file is modified during the bundle build but Xcode checks this dependency
	# before the 'Run Script' phase. By setting the timestamp we are forcing Xcode to recompile
	# the bundle every time.
    REBUILD_CODE_FILENAME="$PROJECT_DIR/RLORebuildCode/RLORebuildCode.m"
    if [ -f $REBUILD_CODE_FILENAME ]; then
    	touch $REBUILD_CODE_FILENAME
    else 
    	echo "warning: $REBUILD_CODE_FILENAME should exist but doesn't"
    fi
fi
