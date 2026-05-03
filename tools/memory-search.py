#!/usr/bin/env python3
"""TF-IDF cosine retrieval over the project memory tree.

Used as a drop-in replacement for `memory-search.sh` when scikit-learn is
available. Same CLI shape as the bash version:

    memory-search.py --query "<q>" [--top-k 5] [--layer l3] [--json]

Override the artefacts directory with $ARTEFACTS_DIR.

Run from the project root.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

try:
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.metrics.pairwise import cosine_similarity
except ImportError:  # pragma: no cover
    sys.stderr.write("sklearn not installed — fall back to memory-search.sh\n")
    sys.exit(2)

ARTEFACTS = Path(os.environ.get("ARTEFACTS_DIR", ".artefacts")).resolve()
MEM_DIR = ARTEFACTS / "memory"

LAYER_WEIGHT = {
    "l4": 4.0,
    "l3": 3.0,
    "l2": 2.0,
    "l1": 2.0,
}


def discover(layer: str | None) -> list[tuple[Path, str]]:
    files: list[tuple[Path, str]] = []

    def add(p: Path, layer_id: str) -> None:
        if p.is_file():
            files.append((p, layer_id))

    if layer in (None, "l4"):
        add(ARTEFACTS / "MEMORY.md", "l4")
    if layer in (None, "l3"):
        for name in ("preferences.md", "system.md", "projects.md", "decisions.md"):
            add(MEM_DIR / name, "l3")
    if layer in (None, "l2"):
        if MEM_DIR.is_dir():
            for p in sorted(MEM_DIR.glob("[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md")):
                files.append((p, "l2"))
    if layer in (None, "l1"):
        add(ARTEFACTS / "SESSION-STATE.md", "l1")

    return files


CHUNK_BREAK = re.compile(r"^(##? |- )", re.MULTILINE)


def chunk_file(p: Path) -> list[tuple[int, int, str]]:
    """Yield (line_start, line_end, text) chunks split on `## ` / `### ` / `- ` boundaries."""
    text = p.read_text(encoding="utf-8", errors="ignore")
    if not text.strip():
        return []
    lines = text.splitlines()
    boundaries = [0]
    for idx, line in enumerate(lines):
        if idx and CHUNK_BREAK.match(line):
            boundaries.append(idx)
    boundaries.append(len(lines))
    out: list[tuple[int, int, str]] = []
    for start, end in zip(boundaries, boundaries[1:]):
        body = "\n".join(lines[start:end]).strip()
        if body:
            out.append((start + 1, end, body))
    return out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--query", required=True)
    ap.add_argument("--top-k", type=int, default=5)
    ap.add_argument("--layer", default=None, choices=[None, "l1", "l2", "l3", "l4"])
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    files = discover(args.layer)
    if not files:
        print("(no memory files yet — run `agentic-kit/tools/memory-init.sh`)")
        return 0

    docs: list[str] = []
    meta: list[tuple[Path, str, int, int]] = []
    for path, layer_id in files:
        for ls, le, body in chunk_file(path):
            docs.append(body)
            meta.append((path, layer_id, ls, le))

    if not docs:
        print("(memory is empty)")
        return 0

    vec = TfidfVectorizer(
        lowercase=True,
        token_pattern=r"(?u)\b\w{3,}\b",
        ngram_range=(1, 2),
        max_df=0.9,
    )
    matrix = vec.fit_transform(docs + [args.query])
    q_vec = matrix[-1]
    d_mat = matrix[:-1]
    sims = cosine_similarity(q_vec, d_mat).flatten()

    # Apply layer boost
    boosted = [(sims[i] * LAYER_WEIGHT[meta[i][1]], i) for i in range(len(docs))]
    boosted.sort(reverse=True)

    top = boosted[: args.top_k]
    if args.json:
        for score, i in top:
            if score <= 0:
                continue
            path, layer_id, ls, le = meta[i]
            snippet = "\n".join(docs[i].splitlines()[:8])
            print(json.dumps({
                "score": round(score, 4),
                "layer": layer_id,
                "file": str(path),
                "line_start": ls,
                "line_end": le,
                "snippet": snippet,
            }))
        return 0

    rank = 0
    for score, i in top:
        if score <= 0:
            continue
        rank += 1
        path, layer_id, ls, le = meta[i]
        snippet = "\n".join("    " + ln for ln in docs[i].splitlines()[:8])
        print(f"\n[{rank}] score={score:.3f} layer={layer_id} — {path}:{ls}-{le}")
        print(snippet)

    if rank == 0:
        print(f"(no matches for: {args.query})")
    return 0


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
