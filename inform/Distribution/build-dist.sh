#!/bin/sh

#
# Andrew Hunter, 26/04/05
# Updated by Toby Nelson, 2014
#
# Shell script to turn Inform into a nice disk image.
#

# Locate Inform.app
if [ -e "../../Inform.app" ]; then
	INFORM="../../Inform.app"
else
	echo "Unable to find Inform.app: giving up"
	exit 1
fi

# resolve symlinks to get original location of file
INFORM=$(readlink $INFORM)

echo "Found Inform.app at '$INFORM'"

# Construct the disk image
if [ -e "/Volumes/Inform" ]; then
	echo "Found something already mounted at /Volumes/Inform: giving up"
	exit 1
fi

if [ -e "pack.temp.dmg" ]; then
	echo "Removing old pack.temp.dmg..."
	rm pack.temp.dmg
fi

if [ -e "inform.dmg" ]; then
	echo "Removing old inform.dmg..."
	rm inform.dmg
fi

echo "Creating pack.temp.dmg..."
hdiutil create -size 80m -fs HFS+ -fsargs "-c c=64,a=16,e=16" -volname "Inform" pack.temp.dmg >/dev/null || (echo Failed; exit 1)

echo "Mounting..."
# hdiutil mount ./pack.temp.dmg -readwrite >/dev/null || (echo Failed; exit 1)
device=$(hdiutil attach -readwrite -noverify -noautoopen "pack.temp.dmg" | egrep '^/dev/' | sed 1q | awk '{print $1}') || (echo Failed; exit 1)

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

cp -Ra "$INFORM" /Volumes/Inform || (echo Failed; exit 1)
mkdir /Volumes/Inform/.background || (echo Failed; exit 1)
cp bgimage.png /Volumes/Inform/.background/bgimage.png || (echo Failed; exit 1)

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
chmod -Rf go-w /Volumes/Inform
sync
sync
hdiutil detach ${device}
hdiutil convert "pack.temp.dmg" -format UDZO -imagekey zlib-level=9 -o "inform.dmg" || (echo Failed; exit 1)
rm -f pack.temp.dmg 

/usr/bin/codesign --force --sign "Developer ID Application: Toby Nelson (97V36B3QYK)" --identifier com.inform7.inform-compiler-dmg Inform.dmg

#hdiutil convert ./inform.dmg -format UDCO -o ./inform-compressed.dmg >/dev/null || (echo Failed; exit 1)

#echo "Adding license info..."
#hdiutil unflatten ./inform-compressed.dmg >/dev/null || (echo Failed; exit 1)
#Rez -a SLA.rez -o inform-compressed.dmg || (echo Failed; exit 1)
#hdiutil flatten ./inform-compressed.dmg >/dev/null || (echo Failed; exit 1)

#mv inform-compressed.dmg inform.dmg

echo OK
