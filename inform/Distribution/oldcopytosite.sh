# Note: The web site is at http://localhost/~tobynelson/index.html

set -e

INFORM_APPDIR=" /Users/tobynelson/Code/git/inform/Distribution/inform.dmg"

# Copy DMG
rm -f ~/Sites/Inform.dmg
cp "$INFORM_APPDIR/Inform.dmg" ~/Sites

#Alternatively: ditto -c -k --sequesterRsrc --keepParent Inform.app ~/Sites/Inform.app.zip
echo "You might want to: cd ~/Sites"
