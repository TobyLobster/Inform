INFORM_APPDIR="/Users/tobynelson/Library/Developer/Xcode/DerivedData/Inform-abfymgdiyeabixberzezqkspixba/Build/Products/Deployment/Inform.app"

echo "************************************************************************************************"
echo "**** Check that the app has few symbols, and the dSYM has lots *********************************"
echo "************************************************************************************************"
echo Inform.app.dSym should have ~15349 lines:
wc -l <\/Users/tobynelson/Library/Developer/Xcode/DerivedData/Inform-abfymgdiyeabixberzezqkspixba/Build/Products/Deployment/Inform.app.dSYM/Contents/Resources/DWARF/Inform
echo "************************************************************************************************"
echo Inform.app should report ~299 symbols:
nm -a /Users/tobynelson/Library/Developer/Xcode/DerivedData/Inform-abfymgdiyeabixberzezqkspixba/Build/Products/Deployment/Inform.app/Contents/MacOS/Inform | wc -l


echo "************************************************************************************************"
echo "**** List of all executables in the app ********************************************************"
echo "************************************************************************************************"
find -H "$INFORM_APPDIR" -print0 | xargs -0 file | grep "Mach-O .*"

# verify the code-signing is all correct
echo
echo "************************************************************************************************"
echo "**** Verify the code-signing is all correct ****************************************************"
echo "**** If all is signed correctly, this should say 'accepted' at the end of the line *************"
echo "************************************************************************************************"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/Frameworks/GlkClient.framework/Versions/A/GlkClient"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/Frameworks/GlkClient.framework"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/Frameworks/GlkView.framework/Versions/A/GlkView"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/Frameworks/GlkView.framework"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/Frameworks/ZoomView.framework/Versions/A/Resources/ZoomServer"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/Frameworks/ZoomView.framework/Versions/A/ZoomView"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/Frameworks/ZoomView.framework"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/Library/QuickLook/InformQL.qlgenerator/Contents/MacOS/InformQL"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/MacOS/cBlorb"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/MacOS/inform6"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/MacOS/ni"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/MacOS/git"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/MacOS/glulxe"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/MacOS/Inform"
spctl --verbose=999 --assess "$INFORM_APPDIR/Contents/MacOS/intest"

spctl --verbose=999 --assess --type execute "$INFORM_APPDIR"
spctl --verbose=999 --assess --type execute "inform.dmg"

# show information
echo
echo "************************************************************************************************"
echo "****************** More ways to get information out of the signed executables ******************"
echo "************************************************************************************************"
codesign -d -r- "$INFORM_APPDIR/Contents/MacOS/Inform"
codesign -d -r- "$INFORM_APPDIR/Contents/Frameworks/GlkClient.framework/Versions/A/GlkClient"
codesign -d -r- "$INFORM_APPDIR/Contents/Frameworks/GlkClient.framework"
codesign -d -r- "$INFORM_APPDIR/Contents/Frameworks/GlkView.framework/Versions/A/GlkView"
codesign -d -r- "$INFORM_APPDIR/Contents/Frameworks/GlkView.framework"
codesign -d -r- "$INFORM_APPDIR/Contents/Frameworks/ZoomView.framework/Versions/A/Resources/ZoomServer"
codesign -d -r- "$INFORM_APPDIR/Contents/Frameworks/ZoomView.framework/Versions/A/ZoomView"
codesign -d -r- "$INFORM_APPDIR/Contents/Frameworks/ZoomView.framework"
codesign -d -r- "$INFORM_APPDIR/Contents/Library/QuickLook/InformQL.qlgenerator/Contents/MacOS/InformQL"
codesign -d -r- "$INFORM_APPDIR/Contents/MacOS/cBlorb"
codesign -d -r- "$INFORM_APPDIR/Contents/MacOS/inform6"
codesign -d -r- "$INFORM_APPDIR/Contents/MacOS/ni"
codesign -d -r- "$INFORM_APPDIR/Contents/MacOS/git"
codesign -d -r- "$INFORM_APPDIR/Contents/MacOS/glulxe"
codesign -d -r- "$INFORM_APPDIR/Contents/MacOS/inform"
codesign -d -r- "$INFORM_APPDIR/Contents/MacOS/intest"
codesign -d -r- "$INFORM_APPDIR"
codesign -d -r- "inform.dmg"

# check mac app signed
#echo
#echo "****************** Check signing details for Mac App Store ******************"
#echo "* Inform *"
#codesign -dvvv --entitlements :- "$INFORM_APPDIR/Contents/MacOS/Inform"
#echo "* ZoomServer *"
#codesign -dvvv --entitlements :- "$INFORM_APPDIR/Contents/Frameworks/ZoomView.framework/Versions/A/Resources/ZoomServer"
#echo "* cBlorb *"
#codesign -dvvv --entitlements :- "$INFORM_APPDIR/Contents/MacOS/cBlorb"
#echo "* inform6 *"
#codesign -dvvv --entitlements :- "$INFORM_APPDIR/Contents/MacOS/inform6"
#echo "* ni *"
#codesign -dvvv --entitlements :- "$INFORM_APPDIR/Contents/MacOS/ni"
#echo "* git *"
#codesign -dvvv --entitlements :- "$INFORM_APPDIR/Contents/MacOS/git"
#echo "* glulxe *"
#codesign -dvvv --entitlements :- "$INFORM_APPDIR/Contents/MacOS/glulxe"
#echo "* inform *"
#codesign -dvvv --entitlements :- "$INFORM_APPDIR/Contents/MacOS/inform"
#echo "* intest *"
#codesign -dvvv --entitlements :- "$INFORM_APPDIR/Contents/MacOS/intest"
