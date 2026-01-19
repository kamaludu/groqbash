#!/usr/bin/env bash
set -euo pipefail

# tests/smoke.sh
# Smoke tests minimi per GroqShell: --version e --dry-run (payload JSON)
# Exit codes:
#  0 = success
#  1 = generic failure (test assertion)
#  2 = environment/setup failure

GROQSH="./bin/groqshell"

echo "Eseguo smoke test su: $GROQSH"
echo

# Ensure the script exists and is executable
if [ ! -x "$GROQSH" ]; then
  echo "ERRORE: $GROQSH non trovato o non eseguibile"
  exit 2
fi

# 1) --version
echo "1) Verifica --version"
if "$GROQSH" --version >/dev/null 2>&1; then
  echo "  OK: --version eseguito"
else
  echo "  FAIL: --version fallito"
  exit 1
fi

# 2) --dry-run
echo
echo "2) Verifica --dry-run (payload JSON)"

# Run --dry-run and capture stdout/stderr and exit code
set +e
DRY_OUT="$("$GROQSH" --dry-run "test payload" 2>&1)"
DRY_EXIT=$?
set -e

if [ $DRY_EXIT -ne 0 ]; then
  echo "  FAIL: --dry-run ha restituito exit code $DRY_EXIT"
  echo "  Output:"
  echo "$DRY_OUT"
  exit 1
fi

# Trim leading/trailing whitespace for JSON check
DRY_OUT_TRIMMED="$(printf '%s' "$DRY_OUT" | sed -e 's/^[[:space:]\n\r]*//' -e 's/[[:space:]\n\r]*$//')"

if [ -z "$DRY_OUT_TRIMMED" ]; then
  echo "  FAIL: --dry-run non ha prodotto output"
  exit 1
fi

# Validate JSON: prefer jq, fallback to python3, fallback to a basic heuristic
if command -v jq >/dev/null 2>&1; then
  if printf '%s' "$DRY_OUT_TRIMMED" | jq . >/dev/null 2>&1; then
    echo "  OK: --dry-run ha stampato JSON valido (jq)"
  else
    echo "  FAIL: output non è JSON valido (jq)"
    echo "  Output:"
    echo "$DRY_OUT_TRIMMED"
    exit 1
  fi
elif command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$DRY_OUT_TRIMMED" | python3 -c 'import sys,json; json.load(sys.stdin)' >/dev/null 2>&1; then
    echo "  OK: --dry-run ha stampato JSON valido (python3)"
  else
    echo "  FAIL: output non è JSON valido (python3)"
    echo "  Output:"
    echo "$DRY_OUT_TRIMMED"
    exit 1
  fi
else
  # Basic heuristic: output should start with { or [
  first_char="$(printf '%s' "$DRY_OUT_TRIMMED" | cut -c1)"
  if [ "$first_char" = "{" ] || [ "$first_char" = "[" ]; then
    echo "  WARNING: jq/python3 non installati; output sembra JSON (heuristic)"
    echo "  Output (prima riga):"
    printf '%s\n' "$DRY_OUT_TRIMMED" | head -n 1
    echo "  OK (heuristic)"
  else
    echo "  FAIL: jq/python3 non disponibili e output non sembra JSON"
    echo "  Output:"
    echo "$DRY_OUT_TRIMMED"
    exit 1
  fi
fi

echo
echo "Tutti i test smoke sono passati."
exit 0
