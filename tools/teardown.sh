#!/usr/bin/env bash
# Removes agentic-kit installed copies from the target project.
#
# Order of operations:
#   1. Strip the kit-managed include block from CLAUDE.md / AGENTS.md /
#      .github/copilot-instructions.md  (existing user content is preserved
#      verbatim; only the marked block is removed). If we created the file
#      from scratch as a stub and it still matches what we created, the file
#      is removed entirely.
#   2. Remove kit-installed agent / skill copies under .claude/, .cursor/,
#      .github/ — but only when their SHA-256 still matches the value
#      recorded in .artefacts/.agentic-kit.files. Files you edited locally are kept.
#   3. Remove the canonical pipeline copy at .artefacts/PIPELINE.md
#      when its hash still matches; PROJECT.md is kept unless --full-clean.
#   4. Strip the managed block from .gitignore.
#   5. (--remove-submodule) Deinit the agentic-kit submodule.
#   6. (--full-clean) Offer to remove .artefacts/PROJECT.md and
#      the .artefacts/ folder itself.
#
# Usage: agentic-kit/tools/teardown.sh [--remove-submodule] [--full-clean] [--yes] [--dry-run]
#   --full-clean        Also remove .artefacts/PROJECT.md and the
#                       .artefacts/ directory if empty.
#   --remove-submodule  Also `git submodule deinit` and remove the kit submodule.
#   --yes, -y           Skip confirmation prompts (auto-confirm).
#   --dry-run           Show what would be removed without doing it.
# Run from the project root (parent of the submodule directory).

set -euo pipefail

# shellcheck source=lib.sh
source "$(cd "$(dirname "$0")" && pwd)/lib.sh"

kit_migrate_legacy_root_state

# ---------------------------------------------------------------------------
# Flag parsing (must come before any removal logic)
# ---------------------------------------------------------------------------
show_teardown_help() {
  cat <<'EOF'
agentic-kit / teardown.sh

  Remove agentic-kit installed copies from the current project. Files are
  only deleted when their SHA-256 still matches the manifest — local edits
  are preserved.

  USAGE
    agentic-kit/tools/teardown.sh [--remove-submodule] [--full-clean]
                                  [--yes|-y|--non-interactive|-n] [--dry-run] [--help|-h]

  FLAGS
    --remove-submodule   Also `git submodule deinit` and remove the kit submodule.
    --full-clean         Also remove .artefacts/PROJECT.md and the
                         .artefacts/ folder if empty.
    --yes, -y            Skip confirmation prompts. Aliases: --non-interactive, -n.
    --dry-run            Show what would be removed without doing it.
    --help, -h           Show this help and exit.
EOF
}

REMOVE_SUBMODULE=false
FULL_CLEAN=false
YES=false
DRY_RUN=false
for _arg in "$@"; do
  case "$_arg" in
    --help|-h)                       show_teardown_help; exit 0 ;;
    --remove-submodule)              REMOVE_SUBMODULE=true ;;
    --full-clean)                    FULL_CLEAN=true ;;
    --yes|-y|--non-interactive|-n)   YES=true ;;
    --dry-run)                       DRY_RUN=true ;;
  esac
done
# Non-interactive (no TTY) auto-enables --yes
[ ! -t 0 ] && YES=true

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
printf "\n${BOLD}${CYAN}  ╭─────────────────────────────╮${RESET}\n"
printf "${BOLD}${CYAN}  │    agentic-kit teardown     │${RESET}\n"
printf "${BOLD}${CYAN}  ╰─────────────────────────────╯${RESET}\n"
info "project root: $PROJECT_ROOT"
info "artefacts:    $ARTEFACTS_DIR_NAME/"
$DRY_RUN && warn "Dry run — no files will be removed."

# ---------------------------------------------------------------------------
# Dry-run-aware removal helpers
# ---------------------------------------------------------------------------
do_rm() {
  if $DRY_RUN; then
    info "would remove: $1"
  else
    rm "$1"
  fi
}
do_rm_rf() {
  if $DRY_RUN; then
    info "would remove: $1"
  else
    rm -rf "$1"
  fi
}

_manifest_drop() {
  if ! $DRY_RUN; then manifest_remove_entry "$1"; fi
}

# Remove a regular file if manifest hash matches (or legacy kit marker + no manifest).
teardown_managed_file() {
  local rel="$1"
  local abs="$PROJECT_ROOT/$rel"
  local recorded have

  if [ ! -e "$abs" ] && [ ! -L "$abs" ]; then
    _manifest_drop "$rel"
    return 0
  fi

  if [ -L "$abs" ] && kit_symlink_points_into_kit "$abs"; then
    do_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel (legacy symlink)"
    return 0
  fi

  if [ ! -f "$abs" ] || [ -L "$abs" ]; then
    skip "$rel (not a regular file — delete manually)"
    return 1
  fi

  have=$(kit_sha256_file "$abs") || true
  recorded=$(manifest_get_hash "$rel" || true)

  if [ -n "$recorded" ] && [ -n "$have" ] && [ "$have" = "$recorded" ]; then
    do_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel"
    return 0
  fi

  if [ -z "$recorded" ] && grep -qF "$AGENTIC_MARKER" "$abs" 2>/dev/null; then
    do_rm "$abs"
    _manifest_drop "$rel"
    removed "$rel (legacy kit marker, no manifest)"
    return 0
  fi

  skip "$rel (modified or unknown — hash mismatch or not kit-managed)"
}

# Remove a copied skill tree if manifest hash matches (or matches live kit source).
teardown_managed_tree() {
  local rel="$1"
  local kit_src="$2"
  local abs="$PROJECT_ROOT/$rel"
  local recorded have want

  if [ ! -e "$abs" ] && [ ! -L "$abs" ]; then
    _manifest_drop "$rel"
    return 0
  fi

  if [ -L "$abs" ] && kit_symlink_points_into_kit "$abs"; then
    do_rm_rf "$abs"
    _manifest_drop "$rel"
    removed "$rel (legacy symlink)"
    return 0
  fi

  if [ ! -d "$abs" ] || [ -L "$abs" ]; then
    skip "$rel (not a directory — delete manually)"
    return 1
  fi

  have=$(kit_sha256_tree "$abs") || true
  recorded=$(manifest_get_hash "$rel" || true)

  if [ -n "$recorded" ] && [ -n "$have" ] && [ "$have" = "$recorded" ]; then
    do_rm_rf "$abs"
    _manifest_drop "$rel"
    removed "$rel"
    return 0
  fi

  if [ -z "$recorded" ] && [ -d "$kit_src" ]; then
    want=$(kit_sha256_tree "$kit_src") || true
    if [ -n "$want" ] && [ -n "$have" ] && [ "$have" = "$want" ]; then
      do_rm_rf "$abs"
      _manifest_drop "$rel"
      removed "$rel (matches kit source, no manifest)"
      return 0
    fi
  fi

  skip "$rel (modified locally — hash mismatch)"
}

# Strip the kit-managed include block from $rel (a project-relative path).
# Behaviour:
#   * if the manifest entry says "stub:<sha>" and the file still matches that
#     stub byte-for-byte (we created it), remove the whole file
#   * else strip just the marked block and keep the rest of the file
#   * always drop the manifest entry
teardown_include_block() {
  local rel="$1"
  local abs="$PROJECT_ROOT/$rel"
  local recorded prefix value have

  if [ ! -f "$abs" ]; then
    _manifest_drop "$rel"
    return 0
  fi

  recorded=$(manifest_get_hash "$rel" || true)
  prefix="${recorded%%:*}"
  value="${recorded#*:}"

  if [ "$prefix" = "stub" ] && [ -n "$value" ]; then
    have=$(kit_sha256_file "$abs" || true)
    if [ -n "$have" ] && [ "$have" = "$value" ]; then
      do_rm "$abs"
      _manifest_drop "$rel"
      removed "$rel (kit-created stub)"
      return 0
    fi
  fi

  if agentic_block_present "$abs"; then
    if $DRY_RUN; then
      info "would strip managed include block from: $rel"
      return 0
    fi
    if agentic_block_strip "$abs"; then
      _manifest_drop "$rel"
      removed "$rel (managed block stripped, file kept)"
      return 0
    fi
    warn "$rel (failed to strip block — left as-is)"
    return 1
  fi

  if [ -n "$recorded" ]; then
    skip "$rel (no managed block found — manifest entry dropped)"
    _manifest_drop "$rel"
    return 0
  fi

  skip "$rel (no managed block — leaving file alone)"
}

# Strip the managed block from .gitignore.
teardown_gitignore_block() {
  local rel=".gitignore"
  local abs="$PROJECT_ROOT/$rel"

  if [ ! -f "$abs" ]; then
    _manifest_drop "$rel"
    info ".gitignore not present"
    return 0
  fi

  if agentic_gitignore_present "$abs"; then
    if $DRY_RUN; then
      info "would strip managed block from: $rel"
      return 0
    fi
    if agentic_gitignore_strip "$abs"; then
      _manifest_drop "$rel"
      removed ".gitignore (managed block stripped, file kept)"
      # If we just emptied .gitignore (file existed only because we created it
      # for the block), remove it.
      if [ ! -s "$abs" ]; then
        do_rm "$abs"
        removed ".gitignore (was empty after strip)"
      fi
      return 0
    fi
    warn ".gitignore (failed to strip block — left as-is)"
    return 1
  fi

  _manifest_drop "$rel"
  skip ".gitignore (no managed block — leaving file alone)"
}

# ---------------------------------------------------------------------------
# 1. Strip include blocks from entry-point files
# ---------------------------------------------------------------------------
header "Entry-point files (managed include blocks)"
teardown_include_block "CLAUDE.md"
teardown_include_block "AGENTS.md"
teardown_include_block ".github/copilot-instructions.md"

# ---------------------------------------------------------------------------
# 2. Remove Claude agents (copies)
# ---------------------------------------------------------------------------
header "Agents"

for agent in "$SCRIPT_DIR/agents/"*.md; do
  [ -e "$agent" ] || continue
  name=$(basename "$agent")
  teardown_managed_file ".claude/agents/$name"
done
if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.claude/agents" ] && [ -z "$(ls -A "$PROJECT_ROOT/.claude/agents" 2>/dev/null)" ]; then
  rmdir "$PROJECT_ROOT/.claude/agents" 2>/dev/null && removed ".claude/agents/ (empty dir)" || true
fi

# ---------------------------------------------------------------------------
# 3. Remove Claude skill copies
# ---------------------------------------------------------------------------
header "Skills"

for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  teardown_managed_tree ".claude/skills/$name" "${skill_dir%/}"
done
if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.claude/skills" ] && [ -z "$(ls -A "$PROJECT_ROOT/.claude/skills" 2>/dev/null)" ]; then
  rmdir "$PROJECT_ROOT/.claude/skills" 2>/dev/null && removed ".claude/skills/ (empty dir)" || true
fi
if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.claude" ] && [ -z "$(ls -A "$PROJECT_ROOT/.claude" 2>/dev/null)" ]; then
  rmdir "$PROJECT_ROOT/.claude" 2>/dev/null && removed ".claude/ (empty dir)" || true
fi

# ---------------------------------------------------------------------------
# 4. Remove Cursor skill copies, subagents, legacy rules
# ---------------------------------------------------------------------------
header "Cursor"

for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  [ -d "$skill_dir" ] || continue
  name=$(basename "$skill_dir")
  teardown_managed_tree ".cursor/skills/$name" "${skill_dir%/}"
done
if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.cursor/skills" ] && [ -z "$(ls -A "$PROJECT_ROOT/.cursor/skills" 2>/dev/null)" ]; then
  rmdir "$PROJECT_ROOT/.cursor/skills" 2>/dev/null && removed ".cursor/skills/ (empty dir)" || true
fi

if [ -d "$PROJECT_ROOT/.cursor/agents" ]; then
  for sf in "$PROJECT_ROOT/.cursor/agents/"*.md; do
    [ -e "$sf" ] || continue
    teardown_managed_file ".cursor/agents/$(basename "$sf")"
  done
  if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.cursor/agents" ] && [ -z "$(ls -A "$PROJECT_ROOT/.cursor/agents" 2>/dev/null)" ]; then
    rmdir "$PROJECT_ROOT/.cursor/agents" 2>/dev/null && removed ".cursor/agents/ (empty dir)" || true
  fi
else
  info ".cursor/agents/ not present"
fi

if [ -d "$PROJECT_ROOT/.cursor/rules" ]; then
  for mdc in "$PROJECT_ROOT/.cursor/rules/"*.mdc; do
    [ -e "$mdc" ] || continue
    teardown_managed_file ".cursor/rules/$(basename "$mdc")"
  done
  if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.cursor/rules" ] && [ -z "$(ls -A "$PROJECT_ROOT/.cursor/rules" 2>/dev/null)" ]; then
    rmdir "$PROJECT_ROOT/.cursor/rules" 2>/dev/null && removed ".cursor/rules/ (empty dir)" || true
  fi
else
  info ".cursor/rules/ not present"
fi
if ! $DRY_RUN && [ -d "$PROJECT_ROOT/.cursor" ] && [ -z "$(ls -A "$PROJECT_ROOT/.cursor" 2>/dev/null)" ]; then
  rmdir "$PROJECT_ROOT/.cursor" 2>/dev/null && removed ".cursor/ (empty dir)" || true
fi

# ---------------------------------------------------------------------------
# 5. Remove GitHub Copilot generated files
# ---------------------------------------------------------------------------
header "GitHub Copilot"

GITHUB_DIR="$PROJECT_ROOT/.github"

if [ -d "$GITHUB_DIR/agents" ]; then
  for f in "$GITHUB_DIR/agents/"*.agent.md; do
    [ -e "$f" ] || continue
    teardown_managed_file ".github/agents/$(basename "$f")"
  done
  if ! $DRY_RUN; then
    [ -z "$(ls -A "$GITHUB_DIR/agents" 2>/dev/null)" ] && rmdir "$GITHUB_DIR/agents" 2>/dev/null && removed ".github/agents/ (empty dir)" || true
  fi
else
  info ".github/agents/ not present"
fi

if [ -d "$GITHUB_DIR/instructions" ]; then
  for f in "$GITHUB_DIR/instructions/"*.instructions.md; do
    [ -e "$f" ] || continue
    teardown_managed_file ".github/instructions/$(basename "$f")"
  done
  if ! $DRY_RUN; then
    [ -z "$(ls -A "$GITHUB_DIR/instructions" 2>/dev/null)" ] && rmdir "$GITHUB_DIR/instructions" 2>/dev/null && removed ".github/instructions/ (empty dir)" || true
  fi
else
  info ".github/instructions/ not present"
fi
if ! $DRY_RUN && [ -d "$GITHUB_DIR" ] && [ -z "$(ls -A "$GITHUB_DIR" 2>/dev/null)" ]; then
  rmdir "$GITHUB_DIR" 2>/dev/null && removed ".github/ (empty dir)" || true
fi

# ---------------------------------------------------------------------------
# 6. Remove .artefacts/PIPELINE.md (kit-managed copy)
# ---------------------------------------------------------------------------
header "$ARTEFACTS_DIR_NAME/ (canonical pipeline copy)"
teardown_managed_file "$ARTEFACTS_DIR_NAME/PIPELINE.md"

# ---------------------------------------------------------------------------
# 7. Strip managed .gitignore block
# ---------------------------------------------------------------------------
header ".gitignore (managed block)"
teardown_gitignore_block

# ---------------------------------------------------------------------------
# 8. Optionally remove the submodule
# ---------------------------------------------------------------------------
if $REMOVE_SUBMODULE && ! $DRY_RUN; then
  header "Submodule"
  cd "$PROJECT_ROOT"
  git submodule deinit -f "$SUBMODULE_DIR" 2>/dev/null || true
  git rm -f "$SUBMODULE_DIR" 2>/dev/null || true
  do_rm_rf ".git/modules/$SUBMODULE_DIR"
  removed "submodule $SUBMODULE_DIR"
elif $REMOVE_SUBMODULE && $DRY_RUN; then
  header "Submodule"
  info "would deinit and remove submodule $SUBMODULE_DIR"
fi

# ---------------------------------------------------------------------------
# 9. Optionally remove PROJECT.md and the artefacts dir (--full-clean)
# ---------------------------------------------------------------------------
if $FULL_CLEAN; then
  header "Full clean — $ARTEFACTS_DIR_NAME/PROJECT.md and friends"
  _confirm_remove() {
    local rel="$1"
    local abs="$PROJECT_ROOT/$rel"
    if [ ! -f "$abs" ]; then
      info "$rel not present"
      return
    fi
    if $DRY_RUN; then
      info "would remove: $rel"
      return
    fi
    if $YES; then
      rm "$abs"
      removed "$rel"
      return
    fi
    local _yn
    if [ -t 0 ]; then
      printf "  ${YELLOW}⚠${RESET} Remove ${BOLD}%s${RESET}? [y/N] " "$rel"
      read -r -n1 _yn; printf '\n'
    elif { : >/dev/tty; } 2>/dev/null; then
      printf "  ${YELLOW}⚠${RESET} Remove ${BOLD}%s${RESET}? [y/N] " "$rel" >/dev/tty
      read -r _yn </dev/tty
    else
      info "$rel kept (no TTY — use --yes to remove, or delete manually)"
      return
    fi
    if [[ "${_yn:-N}" =~ ^[Yy]$ ]]; then
      rm "$abs"
      removed "$rel"
    else
      skip "$rel (kept)"
    fi
  }

  _confirm_remove "$ARTEFACTS_DIR_NAME/PROJECT.md"
  _manifest_drop "$ARTEFACTS_DIR_NAME/PROJECT.md"

  # Try to remove the artefacts directory if empty (it usually still has
  # memory/, features/, archive/ — those are user state, not kit-managed).
  if [ -d "$ARTEFACTS_DIR" ] && ! $DRY_RUN; then
    rmdir "$ARTEFACTS_DIR" 2>/dev/null \
      && removed "$ARTEFACTS_DIR_NAME/ (empty dir)" \
      || info "$ARTEFACTS_DIR_NAME/ kept (still contains memory/features/archive — delete manually if desired)"
  elif $DRY_RUN; then
    info "would attempt rmdir $ARTEFACTS_DIR_NAME/ (kept if non-empty)"
  fi

  if [ -f "$KIT_CFG" ] && ! $DRY_RUN; then
    rm "$KIT_CFG" && removed ".artefacts/.agentic-kit.cfg"
  elif [ -f "$KIT_CFG" ] && $DRY_RUN; then
    info "would remove: $ARTEFACTS_DIR_NAME/.agentic-kit.cfg"
  fi
fi

# ---------------------------------------------------------------------------
# Stale config files
# ---------------------------------------------------------------------------
if ! $DRY_RUN; then
  if [ -f "$KIT_FILES_MANIFEST" ] && [ ! -s "$KIT_FILES_MANIFEST" ]; then
    rm "$KIT_FILES_MANIFEST" && removed "$ARTEFACTS_DIR_NAME/.agentic-kit.files (empty)"
  fi
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
printf "\n${BOLD}${GREEN}  ✓ Done.${RESET}\n"
if ! $FULL_CLEAN; then
  info "$ARTEFACTS_DIR_NAME/PROJECT.md kept — use --full-clean to remove it."
fi
if ! $REMOVE_SUBMODULE; then
  info "Submodule kept — use --remove-submodule to deinit."
fi
$DRY_RUN && warn "Dry run complete — rerun without --dry-run to apply."
printf '\n'
