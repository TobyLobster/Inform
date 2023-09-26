#
# Copies resources to target build.
# Executed as part of the 'final_build_phase.sh' script.
#

# Some executables and resources for the app originate from the core of Graham Nelson's Inform.
# If the "INFORM_CORE" directory exists, these resources are built and copied into the TempStagingArea.
# Resources from TempStagingArea are copied into the StagingArea proper as needed.
# The StagingArea files are then copied to the target build.
export INFORM_CORE="${SRCROOT}/../../Inform Core/inform"
export INFORM_APP_DIR="${TARGET_BUILD_DIR}"
export STAGING_AREA="${SRCROOT}/StagingArea/Contents"
export TEMP_STAGING_AREA="${SRCROOT}/TempStagingArea/Contents"
export RESOURCE_AREA="${SRCROOT}/Resources"

# Create useful shortcut to App. Not used here, but used when running Distribution/build-dist.sh
# (which creates a DMG file for distribution outside the MAS) to find the Inform App
ln -sf ${INFORM_APP_DIR}/Inform.app ${SRCROOT}/..

#
# If Inform Core exists, get resources from there and put them in the StagingArea
#
if [ -d "${INFORM_CORE}" ]; then
    echo Copy resources to StagingArea - started

    cd "${INFORM_CORE}/.."

    echo INFORM_APP_DIR = $INFORM_APP_DIR
    echo INFORM_CORE = $INFORM_CORE
    pwd

    # If any following commands returns a non-zero result, exit
    set -e

    # If we have not already built Inform into our app (e.g. on a clean build), we clean out
    # the staging area, and (further down) run 'make force' on Inform to ensure everything is
    # copied fresh.
    # Otherwise we do a regular 'make all' on Inform (which is quicker to execute).
    TESTFILE="${INFORM_APP_DIR}/${CONTENTS_FOLDER_PATH}/MacOS/ni"
    echo $TESTFILE
    if [ -f $TESTFILE ];
    then
        # Do nothing
        :
    else
        # Clean build
        if [ -d "${TEMP_STAGING_AREA}" ]; then
            find "${TEMP_STAGING_AREA}" -mindepth 1 -delete
        fi
    fi

    # Make directories in TempStagingArea
    mkdir -p "${TEMP_STAGING_AREA}/MacOS"
    mkdir -p "${TEMP_STAGING_AREA}/Resources"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/Internal"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/Internal/Languages"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/Internal/Languages/English"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/Internal/Languages/French"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/Internal/Languages/German"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/Internal/Languages/Italian"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/Internal/Languages/Spanish"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/Internal/Languages/Swedish"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/Internal/Miscellany"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/English.lproj"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/en.lproj"
    mkdir -p "${TEMP_STAGING_AREA}/Resources/map_icons"

    # Build Inform Core
    if [ -f $TESTFILE ];
    then
        # Incremental build
        echo 'make all'
        make all
    else
        echo 'make force'
        make force
    fi

    cd "${INFORM_CORE}"

    # Make Inform Core build the retrospective executable (and other resource) files
    rm -f retrospective/6L02/*.o
    rm -f retrospective/6L02/cBlorb
    rm -f retrospective/6L02/ni

    rm -f retrospective/6L38/*.o
    rm -f retrospective/6L38/cBlorb
    rm -f retrospective/6L38/ni

    rm -f retrospective/6M62/*.o
    rm -f retrospective/6M62/cBlorb
    rm -f retrospective/6M62/ni

    make -f retrospective/makefile

    #
    # Copy resources from Inform Core into the StagingArea
    #
    set -x

    cp -fr "${INFORM_CORE}/resources/App HTML/"                                 "${TEMP_STAGING_AREA}/Resources/"

    cp -f "${INFORM_CORE}/resources/Imagery/app_images/blurbfile.icns"          "${STAGING_AREA}/Resources/App/Icons/blurbfile.icns"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/i6file.icns"             "${STAGING_AREA}/Resources/App/Icons/i6file.icns"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/i7file.icns"             "${STAGING_AREA}/Resources/App/Icons/i7file.icns"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/i7xfile.icns"            "${STAGING_AREA}/Resources/App/Icons/i7xfile.icns"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/inffile.icns"            "${STAGING_AREA}/Resources/App/Icons/inffile.icns"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/inform.icns"             "${STAGING_AREA}/Resources/App/Icons/inform.icns"

    cp -f "${INFORM_CORE}/resources/Imagery/app_images/informfile.icns"         "${STAGING_AREA}/Resources/App/Icons/informfile.icns"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/materialsfile.icns"      "${STAGING_AREA}/Resources/App/Icons/materialsfile.icns"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/nifile.icns"             "${STAGING_AREA}/Resources/App/Icons/nifile.icns"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/skeinfile.icns"          "${STAGING_AREA}/Resources/App/Icons/skeinfile.icns"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/MaterialsDiagram.png"    "${STAGING_AREA}/Resources/en.lproj/MaterialsDiagram.png"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/Welcome Banner.png"      "${STAGING_AREA}/Resources/Welcome Banner.png"
    cp -f "${INFORM_CORE}/resources/Imagery/app_images/Welcome Banner@2x.png"   "${STAGING_AREA}/Resources/Welcome Banner@2x.png"

    # Copy retrospective files
    cp -f "${INFORM_CORE}/retrospective/retrospective.txt"                      "${STAGING_AREA}/Resources/App/Compilers/retrospective.txt"

    # Copy retrospective executable files
    cp -f "${INFORM_CORE}/retrospective/6L02/cBlorb"                            "${STAGING_AREA}/MacOS/6L02/cBlorb"
    cp -f "${INFORM_CORE}/retrospective/6L02/ni"                                "${STAGING_AREA}/MacOS/6L02/ni"
    cp -f "${INFORM_CORE}/retrospective/6L38/cBlorb"                            "${STAGING_AREA}/MacOS/6L38/cBlorb"
    cp -f "${INFORM_CORE}/retrospective/6L38/ni"                                "${STAGING_AREA}/MacOS/6L38/ni"
    cp -f "${INFORM_CORE}/retrospective/6M62/cBlorb"                            "${STAGING_AREA}/MacOS/6M62/cBlorb"
    cp -f "${INFORM_CORE}/retrospective/6M62/ni"                                "${STAGING_AREA}/MacOS/6M62/ni"

    # Copy retrospective resource files
    cp -rf "${INFORM_CORE}/retrospective/6L02/Extensions"                       "${STAGING_AREA}/Resources/retrospective/6L02"
    # cp -rf "${INFORM_CORE}/retrospective/6L02/I6T/"                             "${STAGING_AREA}/Resources/retrospective/6L02/Extensions/Reserved/"
    cp -rf "${INFORM_CORE}/retrospective/6L38/Internal/"                        "${STAGING_AREA}/Resources/retrospective/6L38"
    cp -rf "${INFORM_CORE}/retrospective/6M62/Internal/"                        "${STAGING_AREA}/Resources/retrospective/6M62"

    # Copy epubs here too...
    cp -f "${INFORM_CORE}/resources/Documentation/Inform - A Design System for Interactive Fiction.epub" "${STAGING_AREA}/Resources/en.lproj/Inform - A Design System for Interactive Fiction.epub"
    cp -f "${INFORM_CORE}/resources/Changes/Changes to Inform.epub"             "${STAGING_AREA}/Resources/en.lproj/Changes to Inform.epub"

    # Copy interpreter executables (for testing extensions) here...
    cp -f "${INFORM_CORE}/inform6/Tests/Assistants/dumb-glulx/glulxe/glulxe"    "${TEMP_STAGING_AREA}/MacOS/"
    cp -f "${INFORM_CORE}/inform6/Tests/Assistants/dumb-frotz/dumb-frotz"       "${TEMP_STAGING_AREA}/MacOS/"

    # Replace the documentation in StagingArea with the latest from TempStagingArea
    rm -f "${STAGING_AREA}/Resources/en.lproj/"*
    mv -f "${TEMP_STAGING_AREA}/Resources/en.lproj/"*                           "${STAGING_AREA}/Resources/en.lproj/"

    rm -f "${STAGING_AREA}/Resources/map_icons/"*
    mv -f "${TEMP_STAGING_AREA}/Resources/map_icons/"*                          "${STAGING_AREA}/Resources/map_icons/"
    rm -f "${STAGING_AREA}/Resources/outcome_images/"*
    mv -f "${TEMP_STAGING_AREA}/Resources/outcome_images/"*                     "${STAGING_AREA}/Resources/outcome_images/"
    rm -f "${STAGING_AREA}/Resources/scene_icons/"*
    mv -f "${TEMP_STAGING_AREA}/Resources/scene_icons/"*                        "${STAGING_AREA}/Resources/scene_icons/"
    rm -f "${STAGING_AREA}/Resources/doc_images/"*
    mv -f "${TEMP_STAGING_AREA}/Resources/doc_images/"*                         "${STAGING_AREA}/Resources/doc_images/"
    rm -f "${STAGING_AREA}/Resources/bg_images/"*
    mv -f "${TEMP_STAGING_AREA}/Resources/bg_images/"*                          "${STAGING_AREA}/Resources/bg_images/"

    mv -f "${TEMP_STAGING_AREA}/Resources/Welcome Background.png"               "${STAGING_AREA}/Resources/Welcome Background.png"

    rm -rf "${STAGING_AREA}/Resources/Internal/"
    mv -f "${TEMP_STAGING_AREA}/Resources/Internal/"                            "${STAGING_AREA}/Resources/Internal/"

    # Move the LATEST version exes to the standard place in the StagingArea
    mv -f "${TEMP_STAGING_AREA}/MacOS/"*                                        "${STAGING_AREA}/MacOS/"

    echo Copy resources to StagingArea - done
fi

# Copy the 404 page to be displayed when the public library is not accessible
# (e.g. because internet connection is down) from the app resources into the staging area.
# This is an 'odd man out' being locally stored in Resources/en.lproj/pl404-macos.html
# and copied into the StagingArea, overwriting the generic, old Inform Core version.
cp -f "${RESOURCE_AREA}/en.lproj/pl404-macos.html"                              "${STAGING_AREA}/Resources/en.lproj/pl404.html"

#
# Remove any "resource fork, Finder information, or similar detritus", otherwise it won't CodeSign
#
echo Remove resource fork and other metadata - start
find "${SRCROOT}/StagingArea/Contents" -type f -print0 | xargs -0 chmod u+rw
find "${SRCROOT}/StagingArea/Contents" -type f -print0 | xargs -0 xattr -c
echo Remove resource fork and other metadata - done

#
# Copy all resources from the StagingArea to the target build Inform.app
#
echo Copy resources from StagingArea - start
cp -rf ${STAGING_AREA} ${INFORM_APP_DIR}/Inform.app

# Add symbolic links to the I6T folder
#ln -sf "${INFORM_APP_DIR}/Inform.app/Contents/Resources/Internal/I6T"       "${INFORM_APP_DIR}/Inform.app/Contents/Resources/retrospective/6L02/I6T"
#ln -sf "${INFORM_APP_DIR}/Inform.app/Contents/Resources/Internal/I6T"       "${INFORM_APP_DIR}/Inform.app/Contents/Resources/retrospective/6L38/I6T"
#ln -sf "${INFORM_APP_DIR}/Inform.app/Contents/Resources/Internal/I6T"       "${INFORM_APP_DIR}/Inform.app/Contents/Resources/retrospective/6M62/I6T"
echo Copy resources from StagingArea - done
