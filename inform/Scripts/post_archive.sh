#!/bin/sh

# Toby Nelson, 2014-2019
#
# Shell script to turn Inform into a nice disk image.
#

env
echo

# Step 1: Export the application
EXPORT_PATH="$TMPDIR/Export"
SRC_ROOT="$WORKSPACE_PATH/../.."
DISTRIBUTION_DIR="$SRC_ROOT/Distribution"
DMG_PATH="$DISTRIBUTION_DIR/inform.dmg"
ZIP_PATH="$DISTRIBUTION_DIR/Inform.zip"

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

echo "Creating pack.temp.dmg..."
hdiutil create -size 95m -fs HFS+ -fsargs "-c c=64,a=16,e=16" -volname "Inform" "$EXPORT_PATH/pack.temp.dmg" >/dev/null || (echo Failed; exit 1)

echo "Mounting..."
# hdiutil mount ./pack.temp.dmg -readwrite >/dev/null || (echo Failed; exit 1)
device=$(hdiutil attach -readwrite -noverify -noautoopen "$EXPORT_PATH/pack.temp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}') || (echo Failed; exit 1)

echo "sleep 5..."
sleep 5
echo $device

if [ -e "/Volumes/Inform" ]; then
	echo OK
else
	echo "Failed to mount: giving up"
	exit 1
fi

# Copy files
echo "Copying files..."

cp -Ra "$INFORM" "/Volumes/Inform" || (echo Failed; exit 1)
mkdir "/Volumes/Inform/.background" || (echo Failed; exit 1)
cp "$DISTRIBUTION_DIR/bgimage.png" "/Volumes/Inform/.background/bgimage.png" || (echo Failed; exit 1)

echo "OK"

# Arrange the icons
echo "Arranging..."

osascript <<NO_MORE_SPOONS
tell application "Finder"
	activate
	set informdisk to disk "Inform"
	set inform to file "Inform.app" of informdisk
	set win to container window of informdisk
	
	-- Location of background image
    set cwd to do shell script "pwd"
	set backgroundFile to "Macintosh HD:Volumes:Inform:.background:bgimage.png"
	
	tell win
		open

		set toolbar visible to false
		set statusbar visible to false
		-- set pathbar visible to false
		set current view to icon view
		set bounds to {200, 200, 750, 600}
		
		set arrangement of icon view options of win to not arranged
		set position of inform to {150, 200}
		set icon size of icon view options of win to 128
		set shows item info of icon view options of win to false
		set shows icon preview of icon view options of win to false
		set background picture of icon view options of win to backgroundFile
		tell informdisk to update without registering applications

		-- Refresh the window
		close win
        delay 1
		open win
        delay 10
	end tell

	-- tell informdisk to eject
end tell
NO_MORE_SPOONS

echo OK

echo "Converting to read only, compressed format..."
chmod -Rf go-w "/Volumes/Inform"
sync
sync
hdiutil detach ${device}
hdiutil convert "$EXPORT_PATH/pack.temp.dmg" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH" || (echo Failed; exit 1)
rm -f "$EXPORT_PATH/pack.temp.dmg" 

/usr/bin/codesign --options=runtime --timestamp --force --sign "Developer ID Application: Toby Nelson (97V36B3QYK)" --identifier com.inform7.inform-compiler-dmg "$DMG_PATH"

#hdiutil convert "$DMG_PATH" -format UDCO -o ./inform-compressed.dmg >/dev/null || (echo Failed; exit 1)

#echo "Adding license info..."
#hdiutil unflatten ./inform-compressed.dmg >/dev/null || (echo Failed; exit 1)
#Rez -a SLA.rez -o inform-compressed.dmg || (echo Failed; exit 1)
#hdiutil flatten ./inform-compressed.dmg >/dev/null || (echo Failed; exit 1)

#mv inform-compressed.dmg "$DMG_PATH"

echo OK

# As a convenience open the folder in the Finder
/usr/bin/open "$DISTRIBUTION_DIR"
