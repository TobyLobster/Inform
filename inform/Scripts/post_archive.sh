#!/bin/sh

# Toby Nelson, 2014-2022
#
# Shell script to turn Inform into a nice fancy disk image.
# Uses create-dmg tool from https://github.com/create-dmg/create-dmg
#

echo "post_archive.sh script running..."

if [ "$CODE_SIGN_IDENTITY" != "Developer ID Application" ]; then
    echo "Exiting script. This is not a Developer ID build, so nothing to do. Code Sign Identity = $CODE_SIGN_IDENTITY"
    exit 0
fi;

# Step 1: Export the application
EXPORT_PATH="$TMPDIR/Export"
SRC_ROOT="$WORKSPACE_PATH/../inform"
DISTRIBUTION_DIR="$SRC_ROOT/Distribution"
DMG_PATH="$DISTRIBUTION_DIR/inform.dmg"
ZIP_PATH="$DISTRIBUTION_DIR/Inform.zip"

env
echo /usr/bin/xcodebuild -exportArchive -archivePath \"$ARCHIVE_PATH\" -exportOptionsPlist \"$DISTRIBUTION_DIR/ExportOptions.plist\" -exportPath \"$EXPORT_PATH\"

/usr/bin/xcodebuild -exportArchive -archivePath "$ARCHIVE_PATH" -exportOptionsPlist "$DISTRIBUTION_DIR/ExportOptions.plist" -exportPath "$EXPORT_PATH"


# Locate Inform.app
if [ -e "$EXPORT_PATH/Inform.app" ]; then
	INFORM="$EXPORT_PATH/Inform.app"
else
	echo "Unable to find Inform.app: giving up"
	exit 1
fi

# resolve symlinks to get original location of file
# INFORM=$(readlink $INFORM)

echo "Found Inform.app at '$INFORM'"

# Construct the disk image
if [ -e "/Volumes/Inform" ]; then
	echo "Found something already mounted at /Volumes/Inform: giving up"
	exit 1
fi

if [ -e "$EXPORT_PATH/pack.temp.dmg" ]; then
	echo "Removing old pack.temp.dmg..."
	rm "$EXPORT_PATH/pack.temp.dmg"
fi

if [ -e "$DMG_PATH" ]; then
	echo "Removing old inform.dmg..."
	rm "$DMG_PATH"
fi

# Uses create-dmg tool from https://github.com/create-dmg/create-dmg
echo Creating fancy DMG...
/usr/local/bin/create-dmg --volname "Inform" --background "$DISTRIBUTION_DIR/bgimage.png" --window-pos 200 200 --window-size 550 400 --icon-size 128 --icon Inform.app 150 195 "$DMG_PATH" "$INFORM"

echo Code signing DMG...
# ${CODE_SIGN_IDENTITY} was 'Developer ID Application: Toby Nelson (97V36B3QYK)'
/usr/bin/codesign --options=runtime --timestamp --force --sign "${CODE_SIGN_IDENTITY}" --identifier com.inform7.inform-compiler-dmg "$DMG_PATH"

echo OK

# As a convenience open the folder in the Finder
/usr/bin/open "$DISTRIBUTION_DIR"
echo "post_archive.sh script finished"
