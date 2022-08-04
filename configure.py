#!/usr/bin/env python3

import argparse
import plistlib
import re
import os
from pbxproj import XcodeProject        # Install from https://github.com/TobyLobster/mod-pbxproj-fork/


# Version numbers
app_version_number          = "1.82"
app_version_build_number    = app_version_number + ".0"
inform_source_version       = "10.1.0"
full_version                = app_version_number + "/6.41/" + inform_source_version

# Helper functions

#
# This function should really be in pbxproj, but they seem to have missed it out.
# (Still, easy enough to write it here.)
#
def set_project_flags(project, flag_name, flags, configuration_name=None):
    """
    Sets the given flags to the flag_name section of the root project on the given configurations
    :param flag_name: name of the flag to be added the values to
    :param flags: A string or array of strings
    :param configuration_name: Configuration name to add the flag to or None for every configuration
    :return: void
    """
    for configuration in project.objects.get_project_configurations(configuration_name):
        configuration.set_flags(flag_name, flags)

#
# Simple .plist file editing
#
def set_in_plist_file(filename, key, val):
    with open(filename, 'rb') as fp:
        pl = plistlib.load(fp)
        pl[key] = val

    with open(filename, 'wb') as fp:
        plistlib.dump(pl, fp)

#
# Simple .strings file editing
#
def replace_in_strings_file(filename, key, val):
    new_lines = []
    with open(filename, "r") as file:
        for line in file:
            # Looking for line with "key = "
            find_pattern = '(^[ \\t]*' + key +' *= *)(.*)'
            replace_pattern = r'\1"' + str(val) + r'";'
            new = re.sub(find_pattern, replace_pattern, line)
            new_lines.append(new)

    with open(filename, "w") as file:
        for line in new_lines:
            file.write(line)
    pass


#########################################################################################
# Argument parsing
#########################################################################################
parser = argparse.ArgumentParser(description='Configure the macOS Inform App for different build types.')

# Add arguments to the parser
build_type = parser.add_mutually_exclusive_group(required=True)
build_type.add_argument('--develop', action='store_true', help="for day to day development; using 'Apple Development' code signing")
build_type.add_argument('--standalone', action='store_true', help="for releasing a non-Mac App Store build; using 'Developer ID' code signing")
build_type.add_argument('--mas', action='store_true', help="for releasing a Mac App Store build; using 'Apple Distribution' code signing")
parser.add_argument('--team', dest='development_team_id')

args = vars(parser.parse_args())

develop = args['develop']
standalone = args['standalone']
mas = args['mas']
development_team = args['development_team_id']

# Default to my development team id
if development_team == None:
    development_team = '97V36B3QYK'


#########################################################################################
# Code signing identity is based on the build type specified
#########################################################################################
if standalone:
    code_sign_identity = 'Developer ID Application'
    sandbox = False
elif develop:
    code_sign_identity = 'Apple Development'
    sandbox = False
elif mas:
    code_sign_identity = 'Apple Distribution'
    sandbox = True
else:
    print("ERROR: Unknown configuration option")
    exit(1)


#########################################################################################
# Submodule XCode Project editing
#########################################################################################

# These are the project files found in various submodules. We are going to edit each of them.
project_filenames = [
    'zoom/ZoomCocoa.xcodeproj/project.pbxproj',
    'zoom/depends/CocoaGlk/CocoaGlk.xcodeproj/project.pbxproj',
    'zoom/depends/CocoaGlk/GlkSound/SFBAudioEngine/Libraries/dumb/dumb.xcodeproj/project.pbxproj',
    'zoom/depends/CocoaGlk/GlkSound/SFBAudioEngine/Libraries/ogg/ogg.xcodeproj/project.pbxproj',
    'zoom/depends/CocoaGlk/GlkSound/SFBAudioEngine/Libraries/vorbis/macosx/Vorbis.xcodeproj/project.pbxproj',
    'zoom/depends/CocoaGlk/GlkSound/SFBAudioEngine/SFBAudioEngine.xcodeproj/project.pbxproj',
]

# Edit each project file in turn
for proj_name in project_filenames:
    # load the project
    project = XcodeProject.load(proj_name)

    # Set code signing flags for the Project
    set_project_flags(project, 'CODE_SIGN_IDENTITY', code_sign_identity)
    set_project_flags(project, 'DEVELOPMENT_TEAM', development_team)
    set_project_flags(project, 'CODE_SIGN_STYLE', 'Manual')

    # Remove code signing flags from all Targets, so that they follow the Project settings
    project.remove_flags('CODE_SIGN_IDENTITY', None)
    project.remove_flags('DEVELOPMENT_TEAM', None)
    project.remove_flags('CODE_SIGN_STYLE', None)
    project.remove_flags('PROVISIONING_PROFILE_SPECIFIER', None)

    # Make both Intel and Apple Silicon versions, always
    project.remove_project_flags('ONLY_ACTIVE_ARCH', None)
    project.remove_flags('ONLY_ACTIVE_ARCH', None)          # Remove setting from all Targets, so they follow the Project settings

    # Set 'Hardened runtime' for the Project
    set_project_flags(project, 'ENABLE_HARDENED_RUNTIME', 'YES')
    project.remove_flags('ENABLE_HARDENED_RUNTIME', None)   # Remove setting from all Targets, so they follow the Project settings


    # Skip install for a few of targets of the ZoomCocoa project
    if proj_name.__contains__('ZoomCocoa.xcodeproj'):
        project.set_flags('SKIP_INSTALL', 'YES', "babel")
        project.set_flags('SKIP_INSTALL', 'YES', "Builder")
        project.set_flags('SKIP_INSTALL', 'YES', "ZoomServer")

    if proj_name.__contains__('CocoaGlk.xcodeproj'):
        project.set_flags('SKIP_INSTALL', 'YES', "GlkView")

    # save the project
    project.save()


#########################################################################################
# Main Inform XCode Project Editing
#########################################################################################

# load the main project
project = XcodeProject.load('inform/Inform.xcodeproj/project.pbxproj')

# Set code signing flags for the Project
set_project_flags(project, 'CODE_SIGN_IDENTITY', code_sign_identity)
set_project_flags(project, 'DEVELOPMENT_TEAM', development_team)
set_project_flags(project, 'CODE_SIGN_STYLE', 'Manual')

# Remove code signing flags from all Targets, so that they follow the Project settings
project.remove_flags('CODE_SIGN_IDENTITY', None)
project.remove_flags('DEVELOPMENT_TEAM', None)
project.remove_flags('CODE_SIGN_STYLE', None)
project.remove_flags('PROVISIONING_PROFILE_SPECIFIER', None)

# Set version number
set_project_flags(project, 'CURRENT_PROJECT_VERSION', app_version_build_number)

# Make both Intel and Apple Silicon versions, always
project.remove_project_flags('ONLY_ACTIVE_ARCH', None)
project.remove_flags('ONLY_ACTIVE_ARCH', None)              # Remove setting from all Targets, so they follow the Project settings

# Set 'Hardened runtime' for the Project
set_project_flags(project, 'ENABLE_HARDENED_RUNTIME', 'YES')
project.remove_flags('ENABLE_HARDENED_RUNTIME', None)       # Remove setting from all Targets, so they follow the Project settings

# save the project
project.save()


#########################################################################################
# plist editing
#########################################################################################
set_in_plist_file("inform/Inform.entitlements",         "com.apple.security.app-sandbox", sandbox)
set_in_plist_file("inform/Inform-inherit.entitlements", "com.apple.security.app-sandbox", sandbox)

# Set app version number
set_in_plist_file("inform/Inform-Info.plist",           "CFBundleVersion", app_version_build_number)
set_in_plist_file("inform/Inform-Info.plist",           "CFBundleShortVersionString", app_version_number)
replace_in_strings_file("inform/Resources/en.lproj/InfoPlist.strings", "CFBundleGetInfoString", "Inform version " + full_version)
replace_in_strings_file("inform/Resources/en.lproj/Localizable.strings", '"Build Version"', inform_source_version)

