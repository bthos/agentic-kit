#!/usr/bin/env bash
# Install primitives shared by init.sh (and any future installer).
# Sourced after shared/lifecycle/tools/lib.sh.
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
# Project-patch blocks (<!-- project-patch:start/end -->) are preserved across
# overwrites: extracted before copy, re-appended after.
install_kit_copy_file() {
  local label="$1" rel_path="$2" src_file="$3"
  local target="$PROJECT_ROOT/$rel_path"
  local want have recorded
  local copy_now=false
  local saved_patches=""

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
    # Before comparing hashes, check if the diff is only project-patch blocks.
    # Strip them to get the "kit-only" content for comparison.
    have=$(kit_sha256_file "$target")
    if [ "$have" = "$want" ]; then
      manifest_set_hash "$rel_path" "$want"
      info "$label (matches kit)"
      return 0
    fi

    # If patches are present, compare the file without them.
    if project_patch_present "$target"; then
      saved_patches=$(project_patch_extract "$target")
      local clean_tmp
      clean_tmp=$(kit_mktemp "tlk-clean") || return 1
      cp "$target" "$clean_tmp"
      project_patch_strip "$clean_tmp" 2>/dev/null || true
      local have_clean
      have_clean=$(kit_sha256_file "$clean_tmp")
      if [ "$have_clean" = "$want" ]; then
        manifest_set_hash "$rel_path" "$have"
        info "$label (matches kit + project patches preserved)"
        return 0
      fi
    fi

    # Branch 3: file exists. Try cheap path: clean git checkout matching kit.
    if [ -n "$recorded" ] && [ "$recorded" = "$want" ] && kit_is_git_clean "$rel_path"; then
      manifest_set_hash "$rel_path" "$want"
      info "$label (matches kit, git-clean)"
      return 0
    fi
    if [ -n "$recorded" ] && [ "$have" = "$recorded" ]; then
      if ! should_overwrite "$label" "$target" "$src_file"; then
        skip "$label (kit updated in submodule — use --force to refresh)"
        return 1
      fi
      rm -f "$target"; copy_now=true
      _post_label="(refreshed from kit)"
    elif [ -n "$recorded" ] && [ "$have" != "$recorded" ]; then
      if ! should_overwrite "$label" "$target" "$src_file"; then
        skip "$label (modified locally — use --force to replace)"
        return 1
      fi
      rm -f "$target"; copy_now=true
      _post_label="(overwritten)"
    else
      if ! should_overwrite "$label" "$target" "$src_file"; then
        skip "$label (exists — use --force)"
        return 1
      fi
      rm -f "$target"; copy_now=true
      _post_label="(overwritten)"
    fi
  fi

  if $copy_now; then
    cp "$src_file" "$target"
    # Re-append project patches that were saved before overwrite
    if [ -n "$saved_patches" ]; then
      printf '\n%s\n' "$saved_patches" >> "$target"
      _post_label="${_post_label:-} + patches preserved"
    fi
    local final_hash
    final_hash=$(kit_sha256_file "$target")
    manifest_set_hash "$rel_path" "$final_hash"
    success "$label ${_post_label:-}"
    unset _post_label
  fi
  return 0
}

# Copy skill directory tree; record aggregate SHA-256 of all files.
# Project-patch blocks in .md files within the tree are preserved across overwrites.
install_kit_copy_tree() {
  local label="$1" rel_path="$2" src_dir="$3"
  local target="$PROJECT_ROOT/$rel_path"
  local want have recorded
  local copy_now=false
  local saved_patches_dir=""

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
      copy_now=true
      _post_label="(refreshed from kit)"
    elif [ -n "$recorded" ] && [ "$have" != "$recorded" ]; then
      if ! should_overwrite "$label"; then
        skip "$label (modified locally — use --force)"
        return 1
      fi
      copy_now=true
      _post_label="(overwritten)"
    else
      if ! should_overwrite "$label"; then
        skip "$label (exists — use --force)"
        return 1
      fi
      copy_now=true
      _post_label="(overwritten)"
    fi
  fi

  if $copy_now; then
    # Save project-patch blocks from .md files before overwriting
    saved_patches_dir=$(kit_mktemp "tlk-tree-patches") || true
    if [ -n "$saved_patches_dir" ] && [ -d "$target" ]; then
      rm -f "$saved_patches_dir"
      mkdir -p "$saved_patches_dir"
      local md_file
      for md_file in "$target"/*.md; do
        [ -f "$md_file" ] || continue
        if project_patch_present "$md_file"; then
          project_patch_extract "$md_file" > "$saved_patches_dir/$(basename "$md_file")"
        fi
      done
    fi

    rm -rf "$target"
    cp -R "$src_dir" "$target"

    # Re-append saved project patches
    local had_patches=false
    if [ -d "$saved_patches_dir" ]; then
      local patch_file
      for patch_file in "$saved_patches_dir"/*.md; do
        [ -f "$patch_file" ] || continue
        local target_md="$target/$(basename "$patch_file")"
        if [ -f "$target_md" ]; then
          printf '\n' >> "$target_md"
          cat "$patch_file" >> "$target_md"
          had_patches=true
        fi
      done
    fi

    local final_hash
    final_hash=$(kit_sha256_tree "$target")
    manifest_set_hash "$rel_path" "$final_hash"
    if $had_patches; then
      _post_label="${_post_label:-} + patches preserved"
    fi
    success "$label ${_post_label:-}"
    unset _post_label
  fi
  return 0
}
