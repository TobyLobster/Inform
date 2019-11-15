# Note: 
#   This is the pre-build step.
#   This action is remarkably well hidden in the project's Scheme, in Build, as a Pre-action.
#   All output from this step is saved to ~/inform_pre_build_output.txt

# Delete the cached version of the plist
rm "${CONFIGURATION_BUILD_DIR}/${INFOPLIST_PATH}"

# Update plist (and strings files) with the current version of Inform in it
/usr/bin/perl ${PROJECT_DIR}/Scripts/replace_versions.pl
