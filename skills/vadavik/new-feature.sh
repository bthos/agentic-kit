#!/usr/bin/env bash
# Creates a new feature folder under .artefacts/features/ with today's date prefix.
# Usage: /skills/vadavik/new-feature.sh <feature-slug>
# Example: /skills/vadavik/new-feature.sh user-login-flow
# Run from project root.

set -euo pipefail

if [ $# -lt 1 ] || [ -z "$1" ]; then
  echo "Usage: $0 <feature-slug>" >&2
  echo "Example: $0 user-login-flow" >&2
  exit 1
fi

SLUG="$1"
DATE=$(date +%Y-%m-%d)
ARTEFACTS="${ARTEFACTS_DIR:-.artefacts}"
FEATURE_DIR="$ARTEFACTS/features/${DATE}-${SLUG}"

if [ -d "$FEATURE_DIR" ]; then
  echo "Feature folder already exists: $FEATURE_DIR"
  echo "FEATURE_PATH=$FEATURE_DIR"
  exit 0
fi

mkdir -p "$FEATURE_DIR"

# Write skeleton spec file
cat > "$FEATURE_DIR/spec.md" <<EOF
# ${SLUG} — Spec

## Summary

[One paragraph: what and why]

## Acceptance Criteria

- [ ] AC1
- [ ] AC2

## Open Questions

- [ ] Question 1

## Deferred Decisions

- None

## Architecture & Test Implications

- [Key dependencies, storage/API surface]

## Documentation Implications

- [What should appear in docs]
EOF

# Write handoff log header
cat > "$FEATURE_DIR/handoff-log.md" <<EOF
# Handoff Log — ${DATE}-${SLUG}

<!-- Append one entry per handoff. Format:
## HH:MM [From] → [To] [context]
Key decisions: ...
Artifacts: ...
-->
EOF

echo "Created: $FEATURE_DIR"
echo "  spec.md         (fill in requirements)"
echo "  handoff-log.md  (agents append entries here)"
echo ""
echo "FEATURE_PATH=$FEATURE_DIR"
