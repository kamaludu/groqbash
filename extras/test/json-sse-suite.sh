#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: extras/test/json-sse-suite.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/kamaludu/groqbash
# =============================================================================
#
# Small test suite for JSON escaping and SSE "content" parsing logic.
# Self-contained; does not call external APIs. Exits non-zero if any test fails.
#
set -euo pipefail

# Simple JSON escaper similar to groqbash's helper but with newline escaping
escape_json_string() {
  # Escape backslash, double-quote, and control characters (newline, tab, carriage return)
  local s="$1"
  s="$(printf '%s' "$s" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g' -e 's/\r/\\r/g' -e 's/\t/\\t/g')"
  printf '%s' "$s"
}

# SSE content parser: extract "content" field value from a JSON-like fragment
# Input: a line like: data: { "content": "Hello \"world\"" }
parse_sse_content() {
  local line="$1"
  # Remove leading "data:" prefix if present
  line="${line#data: }"
  # Use sed to extract the first "content": "..." occurrence (handles escaped quotes)
  # This is a pragmatic parser for test purposes.
  printf '%s' "$line" | sed -nE 's/.*"content"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p'
}

# Test runner
total=0; failed=0

run_test() {
  total=$((total+1))
  local name="$1"; shift
  if "$@"; then
    printf 'PASS: %s\n' "$name"
  else
    printf 'FAIL: %s\n' "$name"
    failed=$((failed+1))
  fi
}

# Tests for escape_json_string
test_escape_simple() {
  local inp='Hello world'
  local out
  out="$(escape_json_string "$inp")"
  [ "$out" = 'Hello world' ]
}

test_escape_quotes() {
  local inp='He said "Hi"'
  local out
  out="$(escape_json_string "$inp")"
  [ "$out" = 'He said \"Hi\"' ]
}

test_escape_backslash() {
  local inp='C:\path\to\file'
  local out
  out="$(escape_json_string "$inp")"
  [ "$out" = 'C:\\path\\to\\file' ]
}

test_escape_newline() {
  local inp='Line1
Line2'
  local out
  out="$(escape_json_string "$inp")"
  [ "$out" = 'Line1\nLine2' ]
}

test_escape_control() {
  local inp=$'Tab\tCR\rEnd'
  local out
  out="$(escape_json_string "$inp")"
  [ "$out" = 'Tab\tCR\rEnd' ]
}

# Tests for parse_sse_content
test_parse_simple() {
  local line='data: {"content":"Hello"}'
  local out
  out="$(parse_sse_content "$line")"
  [ "$out" = 'Hello' ]
}

test_parse_escaped_quotes() {
  local line='data: {"content":"He said \"Hi\" to her"}'
  local out
  out="$(parse_sse_content "$line")"
  [ "$out" = 'He said \"Hi\" to her' ]
}

test_parse_backslashes() {
  local line='data: {"content":"C:\\\\path\\\\file"}'
  local out
  out="$(parse_sse_content "$line")"
  [ "$out" = 'C:\\path\\file' ] || [ "$out" = 'C:\\\\path\\\\file' ]
}

test_parse_multiple_fields() {
  local line='data: {"id":"1","content":"Multi","other":"x"}'
  local out
  out="$(parse_sse_content "$line")"
  [ "$out" = 'Multi' ]
}

test_parse_no_content() {
  local line='data: {"message":"no content here"}'
  local out
  out="$(parse_sse_content "$line" || true)"
  [ -z "$out" ]
}

# Run tests
run_test "escape: simple" test_escape_simple
run_test "escape: quotes" test_escape_quotes
run_test "escape: backslash" test_escape_backslash
run_test "escape: newline" test_escape_newline
run_test "escape: control chars" test_escape_control

run_test "parse SSE: simple" test_parse_simple
run_test "parse SSE: escaped quotes" test_parse_escaped_quotes
run_test "parse SSE: backslashes" test_parse_backslashes
run_test "parse SSE: multiple fields" test_parse_multiple_fields
run_test "parse SSE: no content" test_parse_no_content

printf '\nTest summary: %d total, %d failed\n' "$total" "$failed"

if [ "$failed" -ne 0 ]; then
  exit 2
else
  exit 0
fi
