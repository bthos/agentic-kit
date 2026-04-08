#!/usr/bin/env bash
# Bumps the version in all files listed in PROJECT.md → Project-Specific Configuration → Version files.
# Usage: tools/bump-version.sh [patch|minor]
#   patch — increments Z in X.Y.Z  (Cmok agent calls before each build)
#   minor — increments Y, resets Z  (Zlydni agent calls before commit)
# Run from project root.

set -euo pipefail

TYPE="${1:-patch}"
if [[ "$TYPE" != "patch" && "$TYPE" != "minor" ]]; then
  echo "Usage: $0 [patch|minor]" >&2
  exit 1
fi

PROJECT_MD="${PROJECT_MD:-PROJECT.md}"
if [ ! -f "$PROJECT_MD" ]; then
  echo "Error: $PROJECT_MD not found. Run from project root." >&2
  exit 1
fi

VERSION_LINE=$(grep -m1 'Version files:' "$PROJECT_MD" | sed 's/.*Version files:[[:space:]]*//' | tr -d '`*')

if [ -z "$VERSION_LINE" ]; then
  echo "Error: 'Version files:' not found in $PROJECT_MD." >&2
  exit 1
fi

if [[ "$VERSION_LINE" == *"<"* ]]; then
  echo "Error: Version files still has a placeholder in $PROJECT_MD — fill in the config first." >&2
  exit 1
fi

if [[ "$VERSION_LINE" == "none" ]]; then
  echo "Version files: none — nothing to bump."
  exit 0
fi

bump_json_file() {
  local file
  file=$(echo "$1" | tr -d ' ')
  local bump_type="$2"

  if [ ! -f "$file" ]; then
    echo "  SKIP $file — file not found"
    return
  fi

  local current
  current=$(grep -m1 '"version"' "$file" | grep -o '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' || true)

  if [ -z "$current" ]; then
    echo "  SKIP $file — no \"version\" field found"
    return
  fi

  local major minor patch
  IFS='.' read -r major minor patch <<< "$current"

  local new_version
  if [[ "$bump_type" == "patch" ]]; then
    new_version="$major.$minor.$((patch + 1))"
  else
    new_version="$major.$((minor + 1)).0"
  fi

  # -i.bak is portable: works on both Linux and macOS
  sed -i.bak "s/\"version\": \"$current\"/\"version\": \"$new_version\"/" "$file"
  rm -f "${file}.bak"

  echo "  $file: $current → $new_version"
}

echo "Bumping $TYPE version..."

IFS=',' read -ra FILES <<< "$VERSION_LINE"
for f in "${FILES[@]}"; do
  bump_json_file "$f" "$TYPE"
done

echo "Done."
