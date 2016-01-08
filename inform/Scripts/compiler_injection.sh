#
# Copies resources to target build.
#
# Some executables and resources for the app originate from Graham Nelson's unpublished Inform-Source.
# If Inform-Source exists, these resources are built and copied into the StagingArea.
# The StagingArea files are then copied to the target build.

export INFORMPATH=${TARGET_BUILD_DIR}
export STAGINGAREA=${SRCROOT}/StagingArea/Contents
export RESOURCEAREA=${SRCROOT}/Resources

# Create useful shortcut to App. Not used here, but used when running Distribution/build-dist.sh
# (which creates a DMG file for distribution outside the MAS) to find the Inform App
ln -sf ${INFORMPATH}/Inform.app ${SRCROOT}/..

#
# If Inform-Source exists, get resources from there and put them in the StagingArea
#
if [ -d "${SRCROOT}/../Inform-Source" ]; then
    echo Copy resources to StagingArea - started


    cd ${SRCROOT}/../Inform-Source

    echo INFORMPATH = $INFORMPATH
    pwd

    # If any following commands returns a non-zero result, exit
    set -e

    # 'make force' is required to make sure all Inform-added resource files are copied correctly
    # When we get a new version of Inform, we clean build.
    # If the ni compiler doesn't exist, we 'make force'.
    TESTFILE=${TARGET_BUILD_DIR}/${CONTENTS_FOLDER_PATH}/MacOS/ni
    echo $TESTFILE
    if [ -f $TESTFILE ];
    then
        mkdir -p "${STAGINGAREA}/MacOS"
        mkdir -p "${STAGINGAREA}/Resources"
        mkdir -p "${STAGINGAREA}/Resources/App/Icons"
        mkdir -p "${STAGINGAREA}/Resources/English.lproj"
        mkdir -p "${STAGINGAREA}/Resources/map_icons"

        # Incremental build
        echo 'make all'
        make all
    else
        # Clean build
        if [ -d "${STAGINGAREA}" ]; then
            find "${STAGINGAREA}" -mindepth 1 -delete
        fi

        mkdir -p "${STAGINGAREA}/MacOS"
        mkdir -p "${STAGINGAREA}/Resources"
        mkdir -p "${STAGINGAREA}/Resources/App/Icons"
        mkdir -p "${STAGINGAREA}/Resources/English.lproj"
        mkdir -p "${STAGINGAREA}/Resources/map_icons"

        echo 'make force'
        make force
    fi

    #
    # Copy further resources from inform-source
    #
    set -x

    #cp -f "Imagery/app_images/Blob Logo.png"           "${STAGINGAREA}/Resources/Blob-Logo.png"
    #cp -f "Imagery/app_images/Blob Logo@2x.png"        "${STAGINGAREA}/Resources/Blob-Logo@2x.png"
    #cp -f "Imagery/app_images/buttons/release.png"     "${STAGINGAREA}/Resources/release.png"
    #cp -f "Imagery/app_images/buttons/release@2x.png"  "${STAGINGAREA}/Resources/release@2x.png"
    #cp -f "Imagery/app_images/buttons/replay.png"      "${STAGINGAREA}/Resources/replay.png"
    #cp -f "Imagery/app_images/buttons/replay@2x.png"   "${STAGINGAREA}/Resources/replay@2x.png"
    #cp -f "Imagery/app_images/buttons/run.png"         "${STAGINGAREA}/Resources/run.png"
    #cp -f "Imagery/app_images/buttons/run@2x.png"      "${STAGINGAREA}/Resources/run@2x.png"
    #cp -f "Imagery/app_images/buttons/install.png"     "${STAGINGAREA}/Resources/install.png"
    #cp -f "Imagery/app_images/buttons/install@2x.png"  "${STAGINGAREA}/Resources/install@2x.png"
    #cp -f "Imagery/app_images/installer.png"           "${STAGINGAREA}/Distribution/bgimage.png"

    cp -f "Imagery/app_images/blurbfile.icns"          "${STAGINGAREA}/Resources/App/Icons/blurbfile.icns"
    cp -f "Imagery/app_images/i6file.icns"             "${STAGINGAREA}/Resources/App/Icons/i6file.icns"
    cp -f "Imagery/app_images/i7file.icns"             "${STAGINGAREA}/Resources/App/Icons/i7file.icns"
    cp -f "Imagery/app_images/i7xfile.icns"            "${STAGINGAREA}/Resources/App/Icons/i7xfile.icns"
    cp -f "Imagery/app_images/inffile.icns"            "${STAGINGAREA}/Resources/App/Icons/inffile.icns"
    cp -f "Imagery/app_images/inform.icns"             "${STAGINGAREA}/Resources/App/Icons/inform.icns"

    cp -f "Imagery/app_images/informfile.icns"         "${STAGINGAREA}/Resources/App/Icons/informfile.icns"
    cp -f "Imagery/app_images/Materials Diagram.png"   "${STAGINGAREA}/Resources/English.lproj/MaterialsDiagram.png"
    cp -f "Imagery/app_images/materialsfile.icns"      "${STAGINGAREA}/Resources/App/Icons/materialsfile.icns"
    cp -f "Imagery/app_images/nifile.icns"             "${STAGINGAREA}/Resources/App/Icons/nifile.icns"
    cp -f "Imagery/app_images/skeinfile.icns"          "${STAGINGAREA}/Resources/App/Icons/skeinfile.icns"
    cp -f "Imagery/app_images/Welcome Banner.png"      "${STAGINGAREA}/Resources/Welcome Banner.png"
    cp -f "Imagery/app_images/Welcome Banner@2x.png"   "${STAGINGAREA}/Resources/Welcome Banner@2x.png"
    cp -f "Documentation/Inform - A Design System for Interactive Fiction.epub" "${STAGINGAREA}/Resources/English.lproj/Inform - A Design System for Interactive Fiction.epub"
    cp -f "Changes/Changes to Inform.epub"             "${STAGINGAREA}/Resources/English.lproj/Changes to Inform.epub"

    # Convert to hiDPI compliant tiffs
    tiffutil -cathidpicheck "Imagery/app_images/Blob Logo.png"       "Imagery/app_images/Blob Logo@2x.png"       -out "${STAGINGAREA}/Resources/Blob-Logo.tiff"
    tiffutil -cathidpicheck "${PROJECT_DIR}/Resources/App/Interpreter/Error.png" "${PROJECT_DIR}/Resources/App/Interpreter/Error@2x.png" -out "${STAGINGAREA}/Resources/Error.tiff"

    #########################################################################################
    # HACK: Replace a couple of files (with very slightly changed versions) that otherwise cause the Archive Validation process to crash [Radar 18722024]
    #########################################################################################
    cp -f ${PROJECT_DIR}/Distribution/n_arrow_door_meet.png ${STAGINGAREA}/Resources/map_icons/n_arrow_door_meet.png
    cp -f ${PROJECT_DIR}/Distribution/nw_arrow_door_meet.png ${STAGINGAREA}/Resources/map_icons/nw_arrow_door_meet.png

    echo Copy resources to StagingArea - done
fi

# Convert to hiDPI compliant tiffs
tiffutil -cathidpicheck "${RESOURCEAREA}/App/Toolbar/run.png"     "${RESOURCEAREA}/App/Toolbar/run@2x.png"     -out "${STAGINGAREA}/Resources/run.tiff"
tiffutil -cathidpicheck "${RESOURCEAREA}/App/Toolbar/replay.png"  "${RESOURCEAREA}/App/Toolbar/replay@2x.png"  -out "${STAGINGAREA}/Resources/replay.tiff"
tiffutil -cathidpicheck "${RESOURCEAREA}/App/Toolbar/release.png" "${RESOURCEAREA}/App/Toolbar/release@2x.png" -out "${STAGINGAREA}/Resources/release.tiff"
tiffutil -cathidpicheck "${RESOURCEAREA}/App/Toolbar/test.png"    "${RESOURCEAREA}/App/Toolbar/test@2x.png"    -out "${STAGINGAREA}/Resources/test.tiff"
tiffutil -cathidpicheck "${RESOURCEAREA}/App/Toolbar/install.png" "${RESOURCEAREA}/App/Toolbar/install@2x.png" -out "${STAGINGAREA}/Resources/install.tiff"

#
# Copy resources from the StagingArea to the target build Inform.app
#
echo Copy resources from StagingArea - start
cp -rf ${SRCROOT}/StagingArea/Contents ${INFORMPATH}/Inform.app
echo Copy resources from StagingArea - done
