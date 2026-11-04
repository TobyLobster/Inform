# Note: 
#   This is the final build phase.
#   This action is in the Build Phases of the Inform TARGET.

#########################################################################################
# Make directory for Inform 6 resources
#########################################################################################
echo "****** Make directory for Inform 6 resources ******"
mkdir -p ${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Resources/Library/6.11

#########################################################################################
# Run the compiler injection script
#########################################################################################
echo "****** Run the compiler injection script ******"
. ${PROJECT_DIR}/Scripts/compiler_injection.sh

#########################################################################################
# Copy Inform 6 resources
#########################################################################################
echo "****** Copy Inform 6 library resources ******"

cp -f ${SRCROOT}/Library/lib611/*.h ${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Resources/Library/6.11
printf "6.11" >${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/Resources/Library/Standard


#########################################################################################
# Code sign executables
#########################################################################################
echo "****** Code sign executables ******"

if [ -n "${CODE_SIGN_IDENTITY}" ]; then
    export CODESIGN_ALLOCATE=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/codesign_allocate

    # "Sign to Run Locally" uses identity "-" (ad-hoc). Hardened-runtime flags are not used then.
    if [ "${CODE_SIGN_IDENTITY}" = "-" ]; then
        COMMON='/usr/bin/codesign --force --sign -'
    else
        COMMON="/usr/bin/codesign --timestamp --options=runtime --force --sign \"${CODE_SIGN_IDENTITY}\" --identifier com.inform7.inform-compiler --entitlements \"${PROJECT_DIR}/Inform-inherit.entitlements\""
    fi

    echo "Signing Identity: ${CODE_SIGN_IDENTITY}"
    echo "Signing parameters: ${COMMON}"

# The frameworks are signed when they are copied into the app (Copy Frameworks build phase), so commented out:
#    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/GlkClient.framework/Versions/A/GlkClient"
#    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/GlkView.framework/Versions/A/GlkView"
#    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/ZoomView.framework/Versions/A/ZoomView"

    # ZoomServer is nested inside ZoomView.framework, so it isn't re-signed when the framework is
    # copied, and the Zoom project only signs it to run locally. Sign it here, then re-sign the
    # framework (keeping its identifier, entitlements and flags) so its seal covers the new signature.
    ZOOMVIEW_FRAMEWORK="${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/ZoomView.framework/Versions/A"
    eval ${COMMON} "${ZOOMVIEW_FRAMEWORK}/Resources/ZoomServer"
    /usr/bin/codesign --timestamp --force --sign "${CODE_SIGN_IDENTITY}" --preserve-metadata=identifier,entitlements,flags "${ZOOMVIEW_FRAMEWORK}"

    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/git-client"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/glulxe-client"

#    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/libdumb.a"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/libogg.a"
#    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/libvorbis.a"
#    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${FRAMEWORKS_FOLDER_PATH}/libvorbisfile.a"

    # Sign latest executables
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/inform6"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/intest"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/cBlorb"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/ni"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/inbuild"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/glulxe"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/dumb-frotz"

    # Sign retrospective executables
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/6L02/cBlorb"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/6L02/ni"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/6L38/cBlorb"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/6L38/ni"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/6M62/cBlorb"
    eval ${COMMON} "${BUILT_PRODUCTS_DIR}/${EXECUTABLE_FOLDER_PATH}/6M62/ni"

    echo "Signed!"
else
    echo "No code signing identity found!"
fi

echo "*** Done! ***"
