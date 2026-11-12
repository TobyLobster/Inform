#!/bin/sh
#
# Removes the pages that Inform Core no longer writes from a folder of the documentation (an en.lproj).
# Executed by 'compiler_injection.sh', for the documentation copied from Inform Core and for the app's.
#
# Inform Core writes the documentation into its resources/App HTML folder without removing what earlier
# builds wrote there. So the folder can still have the documentation as it was until 2024 (the doc and
# Rdoc pages, with their indexes and stylesheets), and sections that the documentation no longer has.
# The sections it has are those its manifest.txt lists.
#

DOCUMENTATION="$1"

if [ ! -d "${DOCUMENTATION}" ]; then
    echo "error: There's no documentation at '${DOCUMENTATION}'"
    exit 1
fi

# The documentation as it was until 2024
rm -f "${DOCUMENTATION}/"doc[0-9]*.html "${DOCUMENTATION}/"Rdoc[0-9]*.html
rm -f "${DOCUMENTATION}/allegs.html" "${DOCUMENTATION}/Rallegs.html" "${DOCUMENTATION}/examples_alphabetical.html"
rm -f "${DOCUMENTATION}/indoc_WI.css" "${DOCUMENTATION}/indoc_RB.css"

# Sections of Writing with Inform and the Recipe Book that the manifest doesn't list
if [ -f "${DOCUMENTATION}/manifest.txt" ]; then
    ls "${DOCUMENTATION}" | grep -E '^(WI|RB)_[0-9]+_[0-9]+\.html$' |
        awk -v MANIFEST="${DOCUMENTATION}/manifest.txt" '
            BEGIN { while ((getline line < MANIFEST) > 0) { sub(/:.*/, "", line); listed[line] = 1 } }
            !($0 in listed)' |
        while read -r PAGE; do
            rm -f "${DOCUMENTATION}/${PAGE}"
        done
fi
