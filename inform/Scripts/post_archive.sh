#!/bin/sh

# Toby Nelson, 2014-2019
#
# Shell script to turn Inform into a nice disk image.
#

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

#
# Uses create-dmg tool from https://github.com/create-dmg/create-dmg
#
echo Creating fancy DMG...
/usr/local/bin/create-dmg --volname "Inform" --background "$DISTRIBUTION_DIR/bgimage.png" --window-pos 200 200 --window-size 550 400 --icon-size 128 --icon Inform.app 150 195 "$DMG_PATH" "$INFORM"

echo Code signing DMG...
/usr/bin/codesign --options=runtime --timestamp --force --sign "Developer ID Application: Toby Nelson (97V36B3QYK)" --identifier com.inform7.inform-compiler-dmg "$DMG_PATH"

echo OK

# As a convenience open the folder in the Finder
/usr/bin/open "$DISTRIBUTION_DIR"
