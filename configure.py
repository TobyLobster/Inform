#!/usr/bin/env python3

import argparse
import plistlib
from pbxproj import XcodeProject        # Install from https://github.com/kronenthaler/mod-pbxproj

# Version numbers
app_version_number          = "1.84"
app_version_build_number    = app_version_number + ".0"

# The submodule projects (Zoom, CocoaGlk) are not edited: their frameworks and executables are
# re-signed when they are copied into the app, and inform/Scripts/final_build_phase.sh signs the
# executables nested inside them, so they need no signing settings of their own.

#########################################################################################
# Helper functions
#########################################################################################

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

#########################################################################################
# Argument parsing
#########################################################################################
parser = argparse.ArgumentParser(description='Configure the macOS Inform App for different build types.')

# Add arguments to the parser
build_type = parser.add_mutually_exclusive_group(required=True)
build_type.add_argument('--local', action='store_true',
                        help="for building and running on this Mac only; Xcode 'Sign to Run Locally' (ad-hoc). No Apple Developer team required")
build_type.add_argument('--develop', action='store_true', help="for day to day development; using 'Apple Development' code signing")
build_type.add_argument('--standalone', action='store_true', help="for releasing a non-Mac App Store build; using 'Developer ID' code signing")
build_type.add_argument('--mas', action='store_true', help="for releasing a Mac App Store build; using 'Apple Distribution' code signing")
parser.add_argument('--team', dest='development_team_id',
                    help="Apple Development Team ID (ignored with --local; defaults to the maintainer team for other modes)")

args = vars(parser.parse_args())

local = args['local']
develop = args['develop']
standalone = args['standalone']
mas = args['mas']
development_team = args['development_team_id']

# Default to my development team id, except for --local (Team: None)
if development_team is None and not local:
    development_team = '97V36B3QYK'


#########################################################################################
# Code signing identity is based on the build type specified
#########################################################################################
if local:
    # Xcode UI: Team = None, Signing Certificate = "Sign to Run Locally"
    code_sign_identity = '-'
    sandbox = False
    hardened_runtime = False
    development_team = ''
elif standalone:
    code_sign_identity = 'Developer ID Application'
    sandbox = False
    hardened_runtime = True
elif develop:
    code_sign_identity = 'Apple Development'
    sandbox = False
    hardened_runtime = True
elif mas:
    code_sign_identity = 'Apple Distribution'       # Was '3rd Party Mac Developer Application'
    sandbox = True
    hardened_runtime = True
else:
    print("ERROR: Unknown configuration option")
    exit(1)


#########################################################################################
# Main Inform XCode Project Editing
#########################################################################################

# load the main project
project = XcodeProject.load('inform/Inform.xcodeproj/project.pbxproj')

# Set code signing flags for the Project
set_project_flags(project, 'CODE_SIGN_IDENTITY', code_sign_identity)
set_project_flags(project, 'DEVELOPMENT_TEAM', development_team)
set_project_flags(project, 'CODE_SIGN_STYLE', 'Manual')

# Set sandboxing as needed
set_project_flags(project, 'ENABLE_APP_SANDBOX', 'YES' if sandbox else 'NO')
set_project_flags(project, 'ENABLE_USER_SELECTED_FILES', 'readwrite' if sandbox else '""')
set_project_flags(project, 'PRODUCT_BUNDLE_IDENTIFIER', 'com.inform7.inform-compiler')

# Remove code signing flags from all Targets, so that they follow the Project settings
project.remove_flags('CODE_SIGN_IDENTITY', None)
project.remove_flags('DEVELOPMENT_TEAM', None)
project.remove_flags('CODE_SIGN_STYLE', None)
project.remove_flags('PROVISIONING_PROFILE_SPECIFIER', None)

# Set version number
set_project_flags(project, 'CURRENT_PROJECT_VERSION', app_version_build_number)
set_project_flags(project, 'MARKETING_VERSION', app_version_build_number)

# Make both Intel and Apple Silicon versions, always
project.remove_project_flags('ONLY_ACTIVE_ARCH', None)
project.remove_flags('ONLY_ACTIVE_ARCH', None)              # Remove setting from all Targets, so they follow the Project settings

# Set 'Hardened runtime' for the Project (off for --local / Sign to Run Locally)
set_project_flags(project, 'ENABLE_HARDENED_RUNTIME', 'YES' if hardened_runtime else 'NO')
project.remove_flags('ENABLE_HARDENED_RUNTIME', None)       # Remove setting from all Targets, so they follow the Project settings

# save the project
project.save()

#########################################################################################
# plist editing
#########################################################################################
set_in_plist_file("inform/Inform.entitlements",         "com.apple.security.app-sandbox", sandbox)
set_in_plist_file("inform/Inform-inherit.entitlements", "com.apple.security.app-sandbox", sandbox)

# Application groups require a real team ID; clear them for ad-hoc / Sign to Run Locally.
if local:
    set_in_plist_file("inform/Inform.entitlements", "com.apple.security.application-groups", [])
elif development_team:
    set_in_plist_file("inform/Inform.entitlements", "com.apple.security.application-groups",
                      [development_team + '.com.inform7.inform-compiler'])

# Set app version number
set_in_plist_file("inform/Inform-Info.plist",           "CFBundleVersion", app_version_build_number)
set_in_plist_file("inform/Inform-Info.plist",           "CFBundleShortVersionString", app_version_number)

if local:
    print("Configured for local run: Team None, Sign to Run Locally (ad-hoc).")
    print("Build and run on this Mac only; Gatekeeper will not trust the app for others without re-signing.")
else:
    print(f"Configured with identity '{code_sign_identity}', team '{development_team}'.")

