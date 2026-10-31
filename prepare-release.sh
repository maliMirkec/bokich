#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
PLIST="Info.plist"
CHANGELOG="CHANGELOG.md"
NOTES="dist/release-notes.md"
NEW="${1:-}"
if ! [[ "$NEW" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Usage: ./prepare-release.sh <version>, like 2.1.1" >&2
  exit 1
fi
if git rev-parse -q --verify "refs/tags/v$NEW" >/dev/null 2>&1; then
  echo "Tag v$NEW already exists." >&2
  exit 1
fi
if ! grep -q -x -e "## $NEW" -e "## Unreleased" "$CHANGELOG"; then
  echo "$CHANGELOG needs a \"## $NEW\" or \"## Unreleased\" section." >&2
  exit 1
fi
if grep -q -x "## Unreleased" "$CHANGELOG" && grep -q -x "## $NEW" "$CHANGELOG"; then
  echo "$CHANGELOG has both \"## $NEW\" and \"## Unreleased\". Keep one." >&2
  exit 1
fi
sed -i '' "s/^## Unreleased$/## $NEW/" "$CHANGELOG"
mkdir -p dist
awk -v head="## $NEW" '$0 == head { on = 1; next } /^## / { on = 0 } on' "$CHANGELOG" > "$NOTES"
if ! grep -q '[^[:space:]]' "$NOTES"; then
  echo "The $NEW section in $CHANGELOG is empty." >&2
  exit 1
fi
OLD=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$PLIST")
if [ "$OLD" != "$NEW" ]; then
  BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$PLIST")
  /usr/libexec/PlistBuddy -c "Set CFBundleShortVersionString $NEW" "$PLIST"
  /usr/libexec/PlistBuddy -c "Set CFBundleVersion $((BUILD + 1))" "$PLIST"
fi
./release.sh
cat <<EOF

Prepared $NEW. Nothing is committed or published.

Next steps are in the Release section of README.md.
Release notes: $NOTES
EOF
