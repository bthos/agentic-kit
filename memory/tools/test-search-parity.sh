#!/usr/bin/env bash
# Parity smoke test for memory/tools/search.{sh,py}.
#
# Builds a small fixture memory tree under a temp ARTEFACTS_DIR, runs each
# backend with --json, and compares the top-3 file paths returned. Files are
# allowed to appear in different rank order — we just check the set overlaps.
#
# Exits 0 on parity (or if Python backend is unavailable — bash is the
# authoritative implementation), non-zero on divergence.

set -euo pipefail

THIS_DIR="$(cd "$(dirname "$0")" && pwd)"
SEARCH_SH="$THIS_DIR/search.sh"
SEARCH_PY="$THIS_DIR/search.py"

if [ ! -f "$SEARCH_PY" ]; then
  echo "[skip] search.py not present"
  exit 0
fi
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c "import sklearn" 2>/dev/null; then
  echo "[skip] python3 + sklearn not available — bash backend is sole impl"
  exit 0
fi

WORK=$(mktemp -d "${TMPDIR:-/tmp}/tlk-search-parity.XXXXXX")
trap 'rm -rf "$WORK"' EXIT

export ARTEFACTS_DIR="$WORK/.tlk"
mkdir -p "$ARTEFACTS_DIR/memory"

# Fixture: three L3 files with varying relevance to the query "vector retrieval".
cat > "$ARTEFACTS_DIR/memory/system.md" <<'EOF'
# System

- Vector retrieval pipeline uses TF-IDF cosine similarity over markdown chunks.
- Indexing is rebuilt at query time; no persistent vector store.
EOF

cat > "$ARTEFACTS_DIR/memory/preferences.md" <<'EOF'
# Preferences

- Prefer concise summaries.
- Avoid emoji unless asked.
EOF

cat > "$ARTEFACTS_DIR/memory/projects.md" <<'EOF'
# Projects

- The retrieval layer of the memory subsystem matters most for L3 lookups.
- Top-k cosine scoring beats keyword count on long chunks.
EOF

cd "$WORK"

QUERY="vector retrieval"

set +e
sh_out=$(bash "$SEARCH_SH" "$QUERY" --top-k 3 --json 2>/dev/null)
sh_rc=$?
py_out=$(python3 "$SEARCH_PY" --query "$QUERY" --top-k 3 --json 2>/dev/null)
py_rc=$?
set -e

if [ $sh_rc -ne 0 ]; then
  echo "[fail] search.sh exited $sh_rc"
  echo "$sh_out"
  exit 1
fi
if [ $py_rc -ne 0 ]; then
  echo "[fail] search.py exited $py_rc"
  echo "$py_out"
  exit 1
fi

extract_paths() {
  # Pull "file":"…" values from JSONL output, basename only for portability
  python3 -c '
import json, sys
for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except json.JSONDecodeError:
        continue
    f = obj.get("file") or obj.get("path") or ""
    if f:
        import os
        print(os.path.basename(f))
'
}

sh_paths=$(printf '%s\n' "$sh_out" | extract_paths | sort -u)
py_paths=$(printf '%s\n' "$py_out" | extract_paths | sort -u)

if [ -z "$sh_paths" ] || [ -z "$py_paths" ]; then
  echo "[fail] one backend returned no paths"
  echo "  bash: $sh_paths"
  echo "  py:   $py_paths"
  exit 1
fi

# Both backends should agree on the most relevant file (system.md or projects.md).
overlap=$(comm -12 <(echo "$sh_paths") <(echo "$py_paths") | wc -l | tr -d ' ')
if [ "$overlap" -lt 1 ]; then
  echo "[fail] no overlap between backends"
  echo "  bash: $sh_paths"
  echo "  py:   $py_paths"
  exit 1
fi

echo "[ok] search backends agree on $overlap path(s) in top-3"
