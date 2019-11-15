xcrun altool --notarize-app \
             --primary-bundle-id "com.inform168.zip"  \
             --username "tobymnelson@gmail.com" \
             --password "@keychain:AC_PASSWORD" \
             --file ./inform.dmg
