# Note: The web site is at http://localhost/~tobynelson/index.html

INFORM_APPDIR="/Users/tobynelson/Library/Developer/Xcode/DerivedData/Inform-abfymgdiyeabixberzezqkspixba/Build/Products/Deployment/"

# Zip .app file
cd "${INFORM_APPDIR}"
rm -f ~/Sites/Inform.app.zip
zip -r ~/Sites/Inform.app.zip Inform.app
cd ~/Sites
