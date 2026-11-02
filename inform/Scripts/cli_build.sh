#!/bin/bash
#
# Command line build of the Inform workspace, for checking that everything compiles
# and for tracking compiler warnings. Not used for release builds (see configure.py).
#
# By default this builds Debug without code signing, does not touch Inform Core,
# and does not repoint the Inform.app symlink in the repository root.
#
# Usage: inform/Scripts/cli_build.sh [options]
#   --release            Build the Release configuration instead of Debug
#   --sign               Use the project's code signing settings
#   --update-core        Rebuild Inform Core and refresh StagingArea (INFORM_CORE_UPDATE=YES)
#   --test               Run the unit tests after building
#   --update-baseline    Replace documentation/warnings_baseline.txt with this build's warnings
#
# Output goes to build/ in the repository root:
#   build/DerivedData    Xcode derived data
#   build/xcodebuild.log Full build log
#   build/warnings.txt   Unique warnings, with paths relative to the repository root
#   build/new_warnings.txt  Warnings not in the baseline (ignoring line numbers)
#

set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
LOG="${BUILD_DIR}/xcodebuild.log"
WARNINGS="${BUILD_DIR}/warnings.txt"
BASELINE="${REPO_ROOT}/documentation/warnings_baseline.txt"

CONFIGURATION=Debug
ACTION=build
UPDATE_CORE=NO
UPDATE_BASELINE=NO
SIGNING_SETTINGS=(CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=)

while [ $# -gt 0 ]; do
    case "$1" in
        --release)          CONFIGURATION=Release ;;
        --sign)             SIGNING_SETTINGS=() ;;
        --update-core)      UPDATE_CORE=YES ;;
        --test)             ACTION=test ;;
        --update-baseline)  UPDATE_BASELINE=YES ;;
        *)                  echo "Unknown option: $1"; exit 2 ;;
    esac
    shift
done

mkdir -p "${BUILD_DIR}"
cd "${REPO_ROOT}" || exit 1

echo "Building Inform (${CONFIGURATION}, ${ACTION}); log in ${LOG}"
xcodebuild -workspace Inform.xcworkspace \
           -scheme Inform \
           -configuration "${CONFIGURATION}" \
           -destination 'platform=macOS' \
           -derivedDataPath "${BUILD_DIR}/DerivedData" \
           "${SIGNING_SETTINGS[@]}" \
           INFORM_CORE_UPDATE="${UPDATE_CORE}" \
           INFORM_APP_SYMLINK=NO \
           ${ACTION} > "${LOG}" 2>&1
RESULT=$?

# Collect unique warnings, with paths made relative to the repository root.
# The same warning appears once per architecture, so duplicates are removed.
grep -E ': warning:' "${LOG}" \
    | sed -e "s#${BUILD_DIR}/DerivedData/#DerivedData/#" -e "s#${REPO_ROOT}/##" \
    | sort -u > "${WARNINGS}"

echo
echo "Warnings by flag:"
grep -oE '\[-W[^]]+\]' "${WARNINGS}" | sort | uniq -c | sort -rn | head -20
echo
echo "Unique warnings: $(wc -l < "${WARNINGS}" | tr -d ' ')"
if [ -f "${BASELINE}" ]; then
    echo "Baseline:        $(wc -l < "${BASELINE}" | tr -d ' ')"
    # Compare without line and column numbers, so that edits which only move code don't count as new.
    without_lines() { sed -E 's/:[0-9]+:[0-9]+: warning:/: warning:/' "$1" | sort -u; }
    comm -13 <(without_lines "${BASELINE}") <(without_lines "${WARNINGS}") > "${BUILD_DIR}/new_warnings.txt"
    echo "New since baseline: $(wc -l < "${BUILD_DIR}/new_warnings.txt" | tr -d ' ')  (listed in build/new_warnings.txt)"
fi

if [ "${UPDATE_BASELINE}" = "YES" ]; then
    cp "${WARNINGS}" "${BASELINE}"
    echo "Baseline updated."
fi

echo
grep -E '^\*\* (BUILD|TEST) ' "${LOG}" | tail -1
if [ ${RESULT} -ne 0 ]; then
    echo "Errors:"
    grep -E ': error:' "${LOG}" | sort -u | head -30
fi
exit ${RESULT}
