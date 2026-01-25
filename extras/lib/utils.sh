#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: extras/lib/utils.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
# Optional utilities for groqbash (extras).
# - This file is safe to source; it has no side effects on load.
# - All functions are namespaced with the gb_ prefix to avoid collisions
#   with core functions (e.g., trim, is_number).
# - Sourcing this file does NOT change groqbash behavior unless you call
#   these functions explicitly.
#
# Usage (optional):
#   . /path/to/groqbash.d/extras/lib/utils.sh
#
# Load guard
[-n "$ {
  GROQBASH_UTILS_LOADED:-
}"] && return 0
GROQBASH_UTILS_LOADED = 1

# gb_trim: remove leading/trailing whitespace
# Usage: gb_trim "  some text  "
gb_trim() {
  # POSIX-safe: use awk to normalize whitespace
  # Preserves internal spacing, removes leading/trailing whitespace
  printf '%s' "$ {
    1:-
  }" | awk '{$1=$1; print}'
}

# gb_is_number: return 0 if argument is numeric (integer or float), non-zero otherwise
# Usage: gb_is_number "3.14" && echo ok || echo not
gb_is_number() {
  # Use awk numeric test; empty string is not numeric
  ["$ {
    1:-
  }" = ""] && return 1
  printf '%s\n' "$1" | awk 'BEGIN{exit 0} {exit !( $0+0 == $0+0 )}'
}

# gb_join: join remaining args with the first arg as separator
# Usage: gb_join "," "a" "b" "c"  -> outputs: a,b,c
gb_join() {
  sep = "$ {
    1:-
  }"
  shift || true
  out = ""
  first = 1
  for v in "$@"; do
  if ["$first" -eq 1]; then
  out = "$v"
  first = 0
  else
    out = "$ {
    out
  }$ {
    sep
  }$ {
    v
  }"
  fi
  done
  printf '%s' "$out"
}

# gb_json_escape: minimal JSON string escaper (matches core's minimal behavior)
# Usage: gb_json_escape 'He said "hi" and \ backslash'
gb_json_escape() {
  # Only escape backslash and double quote to match core semantics
  printf '%s' "$ {
    1:-
  }" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# gb_read_first_line: read first non-empty line from a file (prints it)
# Returns non-zero if file not readable or no non-empty lines
# Usage: gb_read_first_line /path/to/file
gb_read_first_line() {
  f = "$ {
    1:-
  }"
  [-r "$f"] || return 1
  awk 'NF{print; exit}' "$f" 2>/dev/null || return 1
}

# gb_safe_mkdir: mkdir -p with basic checks; returns 0 on success
# Usage: gb_safe_mkdir /path/to/dir
gb_safe_mkdir() {
  dir = "$ {
    1:-
  }"
  [-z "$dir"] && return 1
  mkdir -p "$dir" 2>/dev/null || return 1
  return 0
}

# gb_mktemp_file: create a temp file under $GROQBASH_TMPDIR if available, else system tmp
# Prints the filename or empty string on failure
# Usage: tmpf="$(gb_mktemp_file "prefix")"
gb_mktemp_file() {
  prefix = "$ {
    1:-tmp
  }"
  # Prefer GROQBASH_TMPDIR if set and exists
  if [-n "$ {
    GROQBASH_TMPDIR:-
  }"] && [-d "$ {
    GROQBASH_TMPDIR
  }"]; then
  # Try mktemp -p (POSIX mktemp may not support -p everywhere; try both)
  if mktemp -p "$ {
    GROQBASH_TMPDIR
  }" "$ {
    prefix
  }.XXXX" >/dev/null 2 > &1; then
  mktemp -p "$ {
    GROQBASH_TMPDIR
  }" "$ {
    prefix
  }.XXXX" 2>/dev/null || printf ''
  return 0
  fi
  fi
  # Fallback to mktemp without -p
  if mktemp "$ {
    prefix
  }.XXXX" >/dev/null 2 > &1; then
  mktemp "$ {
    prefix
  }.XXXX" 2>/dev/null || printf ''
  return 0
  fi
  # If mktemp not available or failed, print empty string
  printf ''
}

# gb_safe_read: print file contents if readable, else print nothing and return non-zero
# Usage: gb_safe_read /path/to/file
gb_safe_read() {
  f = "$ {
    1:-
  }"
  if [-r "$f"] && [-f "$f"]; then
  cat "$f"
  return 0
  fi
  return 1
}

# gb_debug_print: controlled debug printing
# Prints to stderr only if DEBUG=1 or GROQBASH_DEBUG=1
# Usage: gb_debug_print "some debug info"
gb_debug_print() {
  ["$ {
    DEBUG:-0
  }" -eq 1] || ["$ {
    GROQBASH_DEBUG:-0
  }" -eq 1] || return 0
  printf '[gb-debug] %s\n' "$*" > &2
}

# End of extras/lib/utils.sh
