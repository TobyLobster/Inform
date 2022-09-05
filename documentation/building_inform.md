# Building the macOS Inform App

## 0. Prerequisites

- A recent version of macOS and XCode.
	- At time of writing I'm using XCode 13.4.1 on macOS 12.4 (Monterey).
- *Apple Developer Program* membership, probably. You will need a valid *Code Signing Identity* and *Developer Team*. That means having valid *Provisioning Profiles*, *Certificates* etc configured directly from Apple.
- Python 3.
- Experience of XCode and git.


## 1. Clone the repo and submodules:

```
    git clone --recurse-submodules https://github.com/TobyLobster/Inform.git
```

## 2. Get and install the additional tools:

2a. Install a tool from a github repo that uses Python 3 to edit XCode project files.

- This is required.
- It's my fork of this repo because it needed fixing to work with the ZoomCocoa project.

```
    git clone https://github.com/TobyLobster/mod-pbxproj-fork.git
    cd mod-pbxproj-fork
    sudo python3 setup.py install
```

2b. Optionally install a repo that creates fancy disk images. The install instructions are [here](https://github.com/create-dmg/create-dmg). This is only needed when creating a disk image for release outside the Mac App Store.

## 3. Configure a build:

Before building the app, all project files (including those in recursive submodules), as well as some .plists and .strings files must be configured correctly. This is all automated by a python script found in the root directory. It needs to be executed once, then only when the build type changes or the version number needs to be updated.

* Close any Inform project open in XCode. (XCode doesn't cope well when project files change underneath it.)

* Execute `./configure.py --help`

To see the options. Execute this script with the appropriate parameters specified. Edit the `configure.py` script itself to change the current version number of the App.

* Open the Inform project in XCode.

* After running the configure script always do menu `Product->Clean Build Folder`.

* Now the Inform XCode project should build and run in XCode as normal.

* Troubleshooting: If you're having code signing issues, there is Apple documentation that may help:
	- [XCode Help: If a code signing error occurs](https://help.apple.com/xcode/mac/current/#/dev01865b392).
	- [About Code Signing](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/Introduction/Introduction.html).
	- [Developer Archive: Code Signing in Depth](https://developer.apple.com/library/archive/technotes/tn2206/_index.html#//apple_ref/doc/uid/DTS40007919).
	- [Developer Forums: Manual Code Signing Example](https://developer.apple.com/forums/thread/130855/).
	- [Apple Developer: Code Signing](https://developer.apple.com/support/code-signing/).
	- [Developer Forums: Code Signing](https://developer.apple.com/forums/tags/code-signing/).
	- [Apple Developer: Code Signing Search](https://developer.apple.com/search/?q=Code%20Signing).
	- Deep Dive:
		- [Inside Code Signing: Provisioning Profiles](https://developer.apple.com/documentation/technotes/tn3125-inside-code-signing-provisioning-profiles).
		- [Inside Code Signing: Hashes](https://developer.apple.com/documentation/technotes/tn3126-inside-code-signing-hashes).
		- [Inside Code Signing: Requirements](https://developer.apple.com/documentation/technotes/tn3127-inside-code-signing-requirements/).


# Distributing a build

This whole section is a reminder for me on the procedure for doing this.

- Test everything in the App is working first!

- Check the copyright date in the About box includes the current year.

- Edit `configure.py` to use the latest version numbers.

#### Non-Mac App Store build

- Close XCode.

- Make sure you have installed the `create-dmg` tool as detailed in section 2b. above.

- `./configure.py --standalone --team ...`

- Load the Inform project into XCode.

- In XCode choose menu `Product->Clean Build Folder`

- Choose menu `Product->Archive`
    - This will build the project and create an Archive.
    - The Archiver will appear with your product - WAIT! IT IS NOT DONE YET!
    - It will take a few minutes! It is running a script that:
        - Exports the archive to a temporary location
        - Creates a DMG from the exported Archive.
        - Code Signs the DMG.
        - Opens the `inform/Distribution` directory in the finder. This is how you know it's finished.
        - Logs details to `~/inform_post_archive_output.txt` - check for errors there.
        - FYI:
			- This script is found in `Scripts/post_archive.sh`
        	- It is the post-action step of the Archive action in the XCode Scheme.
        	- This uses a third party tool to create the fancy DMG.

- You should see file `inform/Distribution/inform.dmg` has been produced.

- Troubleshooting: If something went wrong, check the Archive has only the things in it that are needed. If there are extra unwanted executables/libraries in there, then they can be removed by setting SKIP_INSTALL=YES in the appropriate Target. This should be done by adding to the `configure.py` script. The Archive layout should look like this:

```
dSYMs
    Builder.dSYM
    git-client.dSYM
    GlkClient.framework.dSYM
    GlkSound.framework.dSYM
    GlkView.framework.dSYM
    glulxe-client.dSYM
    Inform.app.dSYM
    InformQL.qlgenerator.dSYM
    SFBAudioEngine.framework.dSYM
    ZoomServer.dSYM
    ZoomView.framework.dSYM
Info.plist
Products
    Applications
        Inform.app
SCMBlueprint
    Inform.xcscmblueprint
SwiftSupport
    macosx
        libswiftAppKit.dylib
        libswiftCore.dylib
        libswiftCoreData.dylib
        libswiftCoreFoundation.dylib
        libswiftCoreGraphics.dylib
        libswiftCoreImage.dylib
        libswiftDarwin.dylib
        libswiftDispatch.dylib
        libswiftFoundation.dylib
        libswiftIOKit.dylib
        libswiftMetal.dylib
        libswiftObjectiveC.dylib
        libswiftos.dylib
        libswiftQuartzCore.dylib
        libswiftXPC.dylib
```
See also Apple's documentation [Troubleshooting Application Archiving in Xcode](https://developer.apple.com/library/archive/technotes/tn2215/_index.html).

- Notarize and staple the DMG.
    If you've not done this before, you need to set up your credentials in keychain, as described in the "Upload your app to the notarization service" section of [Customising the notarization workflow](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow?language=objc).

    - First notarize:
        - `cd inform/Distribution`
        - Execute `./notarize.sh`

    - If that succeeds, use the ID returned to run:
        - `xcrun notarytool log <ID> --keychain-profile "AC_PASSWORD" developer_log.json`
        - `open developer_log.json` and check for any errors

    - Finally, staple the DMG:
        - `xcrun stapler staple inform.dmg`

- Rename the DMG with a version number in this format e.g. `Inform_10_1_2_macOS_1_82_2.dmg`

- Done

Troubleshooting: See Apple's documentation:

- [Notarizing macOS software before distribution](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution?language=objc).
- [Customizing the notarization workflow](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution/customizing_the_notarization_workflow?language=objc).
- [Testing a Notarised Product](https://developer.apple.com/forums/thread/130560).



#### Mac App Store build

- Close XCode.

- Execute `./configure.py --mas --team ...`

- Load the Inform project into XCode.

- Choose menu `Product->Archive`
    - This will build the project and create an Archive.

- Note that Notarisation and Stapling is not required for Mac App Store builds.

- Validate the App in the Archiver?

- Then there's a whole bunch more stuff around uploading the Archive to *App Store Connect*, filling in a whole bunch of forms, providing a bunch of screenshots and icons for the app in a variety of defined sizes, descriptions, declarations, etc, submitting the App to Apple for verification, and if everything is OK, finally releasing on the *Mac App Store*.

## Updating to the latest Inform Compiler

- If you haven't already, get and build the Inform Compiler from [here](https://github.com/ganelson/inform), following the instructions there. I call this 'Inform Core' and the macOS app 'InformApp'. So I have folder structure like this:

```
Inform Core\inform
           \intest
           \inweb
           \...

InformApp\inform
         \zoom
         \...
```

- In `scripts/compiler_injection.sh`, make sure INFORM_CORE points to your installed Inform repo. If this directory exists, then building the Inform for macOS app will automatically `make all` and copy in resources from Inform Core. A clean build triggers a `make force` instead.

## Updating Submodules
We have one submodule `zoom`, which has it's own submodules. See [here](https://git-scm.com/book/en/v2/Git-Tools-Submodules) for useful information about how to deal with the crazy world of git submodules.
