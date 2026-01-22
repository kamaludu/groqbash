#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: extras/security/verify.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
#
# Verify provider module files and extras directory permissions.
# Safe, read-only checks only. Exits non-zero on critical errors.
#
set -euo pipefail

# Helper: print status
_ok() { printf 'OK: %s\n' "$*"; }
_warn() { printf 'WARN: %s\n' "$*"; }
_err() { printf 'ERROR: %s\n' "$*"; }

# Determine extras dir variable (support common env name)
GROQBASH_EXTRAS_DIR="${GROQBASH_EXTRAS_DIR:-${GROQBASHEXTRASDIR:-}}"

if [ -z "$GROQBASH_EXTRAS_DIR" ]; then
  _err "GROQBASH_EXTRAS_DIR is not set. Export it to point to your groqbash extras directory."
  exit 2
fi

# Ensure absolute path
case "$GROQBASH_EXTRAS_DIR" in
  /*) : ;;
  *)
    _err "GROQBASH_EXTRAS_DIR must be an absolute path: $GROQBASH_EXTRAS_DIR"
    exit 2
    ;;
esac

# Ensure exists or creatable (do not create automatically; just report)
if [ ! -d "$GROQBASH_EXTRAS_DIR" ]; then
  _err "Extras directory does not exist: $GROQBASH_EXTRAS_DIR"
  exit 2
fi

# Check world-writable for extras dir
_is_world_writable() {
  local d="$1" perms others_write
  [ -d "$d" ] || return 1
  perms="$(ls -ld "$d" 2>/dev/null | awk '{print $1}' 2>/dev/null || true)"
  [ -z "$perms" ] && return 1
  others_write="$(printf '%s' "$perms" | awk '{print substr($0,9,1)}')"
  [ "$others_write" = "w" ]
}

if _is_world_writable "$GROQBASH_EXTRAS_DIR"; then
  _err "Extras directory is world-writable: $GROQBASH_EXTRAS_DIR"
  exit 2
else
  _ok "Extras directory permissions look sane: $GROQBASH_EXTRAS_DIR"
fi

# Providers directory
PROV_DIR="$GROQBASH_EXTRAS_DIR/providers"
if [ ! -d "$PROV_DIR" ]; then
  _warn "Providers directory not found: $PROV_DIR"
  # Not fatal; no providers installed
  exit 0
fi

# Current user
CURRENT_USER="$(id -un 2>/dev/null || printf '')"

# Check for checksum tool
SHA_TOOL=""
if command -v sha256sum >/dev/null 2>&1; then
  SHA_TOOL="sha256sum"
elif command -v shasum >/dev/null 2>&1; then
  SHA_TOOL="shasum -a 256"
fi

# Iterate provider files
any_error=0
printf 'Verifying provider files in: %s\n' "$PROV_DIR"
for f in "$PROV_DIR"/*.sh; do
  [ -e "$f" ] || continue
  printf '\nFile: %s\n' "$f"
  # Existence & regular file
  if [ ! -f "$f" ]; then
    _err "Not a regular file: $f"
    any_error=1
    continue
  else
    _ok "Regular file"
  fi

  # Symlink check
  if [ -L "$f" ]; then
    _err "Provider file is a symlink: $f"
    any_error=1
    continue
  else
    _ok "Not a symlink"
  fi

  # Owner check
  file_owner="$(ls -ld "$f" 2>/dev/null | awk '{print $3}' 2>/dev/null || printf '')"
  if [ -z "$file_owner" ]; then
    _warn "Unable to determine owner for $f"
  else
    if [ "$file_owner" != "$CURRENT_USER" ]; then
      _err "Owner mismatch: $file_owner (expected: $CURRENT_USER) for $f"
      any_error=1
      continue
    else
      _ok "Owned by current user: $CURRENT_USER"
    fi
  fi

  # Permission checks (group/world write)
  perms="$(ls -ld "$f" 2>/dev/null | awk '{print $1}' 2>/dev/null || true)"
  group_write="$(printf '%s' "$perms" | awk '{print substr($0,6,1)}')"
  others_write="$(printf '%s' "$perms" | awk '{print substr($0,9,1)}')"
  if [ "$group_write" = "w" ] || [ "$others_write" = "w" ]; then
    _err "Provider file is writable by group or world: $f (perms: $perms)"
    any_error=1
    continue
  else
    _ok "Not group/world writable (perms: $perms)"
  fi

  # Optional checksum
  if [ -n "$SHA_TOOL" ]; then
    printf 'Checksum: '
    if [ "$SHA_TOOL" = "sha256sum" ]; then
      sha256sum "$f" | awk '{print $1}'
    else
      shasum -a 256 "$f" | awk '{print $1}'
    fi
  else
    _warn "No SHA256 tool found (sha256sum/shasum); skipping checksum"
  fi

  _ok "Provider file passed checks: $f"
done

if [ "$any_error" -ne 0 ]; then
  _err "One or more provider files failed verification."
  exit 2
fi

_ok "All provider files verified successfully."
exit 0
