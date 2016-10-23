# Note: The web site is at http://localhost/~tobynelson/index.html

set -e

INFORM_APPDIR="/Users/tobynelson/Library/Developer/Xcode/DerivedData/Inform-abfymgdiyeabixberzezqkspixba/Build/Products/Deployment/"

# Copy DMG
rm -f ~/Sites/Inform.dmg
cp ./Inform.dmg ~/Sites

# Zip .app file
cd "${INFORM_APPDIR}"
rm -f ~/Sites/Inform.app.zip
zip -ry ~/Sites/Inform.app.zip Inform.app
#Alternatively: ditto -c -k --sequesterRsrc --keepParent Inform.app ~/Sites/Inform.app.zip
#cd ~/Sites
