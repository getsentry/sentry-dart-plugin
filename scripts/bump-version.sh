#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $SCRIPT_DIR/..

OLD_VERSION="${1}"
NEW_VERSION="${2}"

echo "Current version: ${OLD_VERSION}"
echo "Bumping version: ${NEW_VERSION}"

# Bump version in pubspec.yaml
perl -pi -e "s/^version: .*/version: $NEW_VERSION/" pubspec.yaml

# Move a one-off release note (for example a "> [!IMPORTANT]" callout) under
# the new version's heading in CHANGELOG.md, then delete the note file so it
# only ships with this release. Craft has already written the version section
# at this point and commits all changes afterwards.
RELEASE_NOTE=".github/release-note.md"
if [ -s "$RELEASE_NOTE" ]; then
  awk -v heading="## $NEW_VERSION" -v note="$RELEASE_NOTE" '
    { print }
    $0 == heading && !done {
      print ""
      while ((getline line < note) > 0) print line
      done = 1
    }
    END { exit done ? 0 : 1 }
  ' CHANGELOG.md > CHANGELOG.md.tmp || {
    rm -f CHANGELOG.md.tmp
    echo "Could not find '## $NEW_VERSION' in CHANGELOG.md to insert $RELEASE_NOTE" >&2
    exit 1
  }
  mv CHANGELOG.md.tmp CHANGELOG.md
  rm "$RELEASE_NOTE"
  echo "Added $RELEASE_NOTE to the $NEW_VERSION changelog"
fi
