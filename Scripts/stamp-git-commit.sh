#!/bin/sh
#
# Writes the commit a build came from into that build's app bundle, as GitCommit.txt.
# AppVersion.swift reads it back and the Settings screen shows it.
#
# It goes in its own file rather than into Info.plist because the Info.plist in the bundle belongs
# to the build system: it can't be declared as this phase's output ("multiple commands produce…"),
# and without that declaration an incremental build restores it and quietly drops the stamp.
# Nothing else produces GitCommit.txt, so nothing overwrites it. The phase runs after Resources
# and before signing, so the file is sealed into the signature like any other resource.
#
# This is deliberately best-effort. A checkout with no git history, or a build made outside the
# repository, leaves the file out rather than failing the build — the Settings screen then shows
# the version and build number alone.

set -eu

resources="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
[ -d "${resources}" ] || exit 0

# Cleared first, so a build that can't work out the commit shows nothing rather than whatever the
# previous build happened to leave in the bundle.
rm -f "${resources}/GitCommit.txt"

commit=$(git -C "${SRCROOT}" rev-parse --short HEAD 2>/dev/null) || exit 0

# A build made with edits in the tree isn't the commit it would otherwise claim to be.
if ! git -C "${SRCROOT}" diff --quiet HEAD 2>/dev/null; then
    commit="${commit}-dirty"
fi

printf '%s' "${commit}" > "${resources}/GitCommit.txt"
