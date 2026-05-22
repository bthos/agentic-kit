#!/usr/bin/env bash
# Install primitives shared by init.sh (and any future installer).
# Sourced after tools/lib.sh.
#
# Provides:
#   install_kit_copy_file <label> <rel_path> <src_file_abs>
#   install_kit_copy_tree <label> <rel_path> <src_dir_abs>
#
# Both honour the OVERWRITE_ALL/SKIP_ALL/MODE/should_overwrite contract defined
# in init.sh, plus DRY_RUN if the caller sets it. SHA-256 of the kit source is
# computed once and used as the manifest hash after copy (since cp produces an
# identical file, rehashing the target would be redundant).
# shellcheck shell=bash

# Copy kit file into project; record SHA-256 in manifest for teardown.
install_kit_copy_file() {
  local label="$1" rel_path="$2" src_file="$3"
  local target="$PROJECT_ROOT/$rel_path"
  local want have recorded
  local copy_now=false

  want=$(kit_sha256_file "$src_file") || return 1
  mkdir -p "$(dirname "$target")"
  recorded=$(manifest_get_hash "$rel_path" || true)

  # Branch 1: missing or symlink
  if [ ! -e "$target" ] || [ -L "$target" ]; then
    if [ -L "$target" ] && ! should_overwrite "$label"; then
      skip "$label (exists — use --force to replace)"
      return 1
    fi
    [ -L "$target" ] && rm -rf "$target"
    copy_now=true
  # Branch 2: not a regular file (e.g. dir)
  elif [ ! -f "$target" ]; then
    if ! should_overwrite "$label"; then skip "$label (not a regular file)"; return 1; fi
    rm -rf "$target"
    copy_now=true
  else
    # Branch 3: file exists. Try cheap path: clean git checkout matching kit.
    if [ -n "$recorded" ] && [ "$recorded" = "$want" ] && kit_is_git_clean "$rel_path"; then
      manifest_set_hash "$rel_path" "$want"
      info "$label (matches kit, git-clean)"
      return 0
    fi
    have=$(kit_sha256_file "$target")
    if [ "$have" = "$want" ]; then
      manifest_set_hash "$rel_path" "$want"
      info "$label (matches kit)"
      return 0
    fi
    if [ -n "$recorded" ] && [ "$have" = "$recorded" ]; then
      if ! should_overwrite "$label"; then
        skip "$label (kit updated in submodule — use --force to refresh)"
        return 1
      fi
      rm -f "$target"; copy_now=true
      _post_label="(refreshed from kit)"
    elif [ -n "$recorded" ] && [ "$have" != "$recorded" ]; then
      if ! should_overwrite "$label"; then
        skip "$label (modified locally — use --force to replace)"
        return 1
      fi
      rm -f "$target"; copy_now=true
      _post_label="(overwritten)"
    else
      if ! should_overwrite "$label"; then
        skip "$label (exists — use --force)"
        return 1
      fi
      rm -f "$target"; copy_now=true
      _post_label="(overwritten)"
    fi
  fi

  if $copy_now; then
    cp "$src_file" "$target"
    manifest_set_hash "$rel_path" "$want"
    success "$label ${_post_label:-}"
    unset _post_label
  fi
  return 0
}

# Copy skill directory tree; record aggregate SHA-256 of all files.
install_kit_copy_tree() {
  local label="$1" rel_path="$2" src_dir="$3"
  local target="$PROJECT_ROOT/$rel_path"
  local want have recorded
  local copy_now=false

  want=$(kit_sha256_tree "$src_dir") || return 1
  mkdir -p "$(dirname "$target")"
  recorded=$(manifest_get_hash "$rel_path" || true)

  if [ ! -e "$target" ] || [ -L "$target" ]; then
    if [ -L "$target" ] && ! should_overwrite "$label"; then
      skip "$label (exists — use --force to replace)"
      return 1
    fi
    [ -L "$target" ] && rm -rf "$target"
    copy_now=true
  elif [ ! -d "$target" ]; then
    if ! should_overwrite "$label"; then skip "$label (not a directory)"; return 1; fi
    rm -rf "$target"
    copy_now=true
  else
    have=$(kit_sha256_tree "$target")
    if [ "$have" = "$want" ]; then
      manifest_set_hash "$rel_path" "$want"
      info "$label (matches kit)"
      return 0
    fi
    if [ -n "$recorded" ] && [ "$have" = "$recorded" ]; then
      if ! should_overwrite "$label"; then
        skip "$label (kit skill updated — use --force)"
        return 1
      fi
      rm -rf "$target"; copy_now=true
      _post_label="(refreshed from kit)"
    elif [ -n "$recorded" ] && [ "$have" != "$recorded" ]; then
      if ! should_overwrite "$label"; then
        skip "$label (modified locally — use --force)"
        return 1
      fi
      rm -rf "$target"; copy_now=true
      _post_label="(overwritten)"
    else
      if ! should_overwrite "$label"; then
        skip "$label (exists — use --force)"
        return 1
      fi
      rm -rf "$target"; copy_now=true
      _post_label="(overwritten)"
    fi
  fi

  if $copy_now; then
    cp -R "$src_dir" "$target"
    manifest_set_hash "$rel_path" "$want"
    success "$label ${_post_label:-}"
    unset _post_label
  fi
  return 0
}
