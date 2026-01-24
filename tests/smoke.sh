#!/usr/bin/env bash
set -euo pipefail

# tests/smoke.sh - Smoke tests minimi per GroqBash: --version e --dry-run
# Exit codes: 0 success, 1 test failure, 2 environment/setup failure

# Locate groqbash
if [ -x "./bin/groqbash" ]; then
  GROQSH="./bin/groqbash"
elif [ -x "./groqbash" ]; then
  GROQSH="./groqbash"
else
  if command -v groqbash >/dev/null 2>&1; then
    GROQSH="$(command -v groqbash)"
  else
    GROQSH="./bin/groqbash"
  fi
fi

echo "Eseguo smoke test su: $GROQSH"
echo

# ENV diagnostics
echo "=== ENV DIAGNOSTICS ==="
echo "SHELL: ${SHELL:-<unset>}"
echo "TMPDIR: ${TMPDIR:-<unset>}"
echo "HOME: ${HOME:-<unset>}"
echo "XDG_CONFIG_HOME: ${XDG_CONFIG_HOME:-<unset>}"
if [ -n "${GROQ_API_KEY:-}" ]; then
  echo "GROQ_API_KEY: (set)"
else
  echo "GROQ_API_KEY: (unset)"
fi
echo "PATH: $PATH"
echo "=== END ENV DIAGNOSTICS ==="
echo

# Ensure executable exists
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

# Ensure minimal whitelist
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/groq"
MODELS_FILE="$CONFIG_DIR/models.txt"
mkdir -p "$CONFIG_DIR"
if [ ! -s "$MODELS_FILE" ]; then
  echo "test-model-001" > "$MODELS_FILE"
  chmod 600 "$MODELS_FILE"
  echo "  Nota: whitelist temporanea creata in $MODELS_FILE"
fi

echo "=== MODELS WHITELIST ==="
sed -n '1,200p' "$MODELS_FILE" || true
echo "=== END MODELS WHITELIST ==="
echo

PROMPT_TEXT="test payload"
export PROMPT_TEXT

# TMPDIR fallback and checks
TMPDIR_FALLBACK="${HOME}/.cache/groq_tmp"
export TMPDIR="${TMPDIR:-$TMPDIR_FALLBACK}"
mkdir -p "$TMPDIR" 2>/dev/null || true
if [ ! -d "$TMPDIR" ] || [ ! -w "$TMPDIR" ]; then
  echo "ERRORE: TMPDIR ($TMPDIR) non esistente o non scrivibile"
  exit 2
fi

# mktemp helper using TMPDIR
mktemp_safe() {
  local pattern="$1"
  local tmp
  if tmp="$(mktemp "${TMPDIR}/${pattern}" 2>/dev/null)"; then
    printf '%s' "$tmp"
    return 0
  fi
  if tmp="$(mktemp 2>/dev/null)"; then
    printf '%s' "$tmp"
    return 0
  fi
  return 1
}

# Temp files and cleanup
DRY_LOG=""
INPUT_FILE=""
cleanup() {
  [ -n "${DRY_LOG:-}" ] && [ -f "$DRY_LOG" ] && rm -f "$DRY_LOG"
  [ -n "${INPUT_FILE:-}" ] && [ -f "$INPUT_FILE" ] && rm -f "$INPUT_FILE"
}
trap cleanup EXIT

set +e

# Create DRY_LOG
DRY_LOG="$(mktemp_safe groqbash-dry.XXXXXX)" || { echo "Cannot create temp file DRY_LOG"; exit 2; }

# Prepare input JSON: validate tests/good.json if present, otherwise create safe JSON
if [ -f tests/good.json ]; then
  # Validate if possible
  if command -v jq >/dev/null 2>&1; then
    if ! jq . tests/good.json >/dev/null 2>&1; then
      echo "ERRORE: tests/good.json esistente ma non valido JSON"
      sed -n '1,200p' tests/good.json || true
      exit 1
    fi
  elif command -v python3 >/dev/null 2>&1; then
    if ! python3 -c 'import sys,json; json.load(open("tests/good.json"))' >/dev/null 2>&1; then
      echo "ERRORE: tests/good.json esistente ma non valido JSON"
      sed -n '1,200p' tests/good.json || true
      exit 1
    fi
  else
    echo "Nota: tests/good.json presente; non posso validarlo (jq/python3 non disponibili). Procedo con cautela."
  fi
  INPUT_ARG=(--json-input "tests/good.json")
  echo "Using tests/good.json as input"
else
  INPUT_FILE="$(mktemp_safe groqbash-in.XXXXXX)" || { echo "Cannot create input file"; rm -f "$DRY_LOG"; exit 2; }

  # Build JSON safely using python3 if available
  if command -v python3 >/dev/null 2>&1; then
    # Use environment PROMPT_TEXT to avoid shell quoting issues
    python3 - <<'PY' >"$INPUT_FILE"
import json, os, sys
prompt = os.environ.get('PROMPT_TEXT', '')
payload = {
  "model": "test-model-001",
  "stream": False,
  "temperature": 1.0,
  "max_tokens": 4096,
  "messages": [{"role": "user", "content": prompt}]
}
print(json.dumps(payload))
PY
    if [ $? -ne 0 ]; then
      echo "ERRORE: impossibile creare JSON con python3"
      rm -f "$DRY_LOG" "$INPUT_FILE"
      exit 2
    fi
  else
    # Fallback escaping (best-effort)
    esc=$(printf '%s' "$PROMPT_TEXT" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e ':a;N;$!ba;s/\n/\\n/g')
    cat >"$INPUT_FILE" <<JSON
{"model":"test-model-001","stream":false,"temperature":1.0,"max_tokens":4096,"messages":[{"role":"user","content":"$esc"}]}
JSON
  fi

  chmod 600 "$INPUT_FILE"
  INPUT_ARG=(--json-input "$INPUT_FILE")
  echo "Created temporary JSON input at $INPUT_FILE"
fi

# Diagnostics about TMPDIR
echo "TMPDIR in use: $TMPDIR"
echo "Listing TMPDIR (first 50 entries):"
ls -la "$TMPDIR" 2>/dev/null | sed -n '1,50p' || true
echo

# Invoke groqbash deterministically
echo "Invoking: $GROQSH --dry-run ${INPUT_ARG[*]}"
DEBUG=1 "$GROQSH" --dry-run "${INPUT_ARG[@]}" >"$DRY_LOG" 2>&1
DRY_EXIT=$?

# Show raw log for diagnosis
echo "=== groqbash --dry-run raw output (begin) ==="
sed -n '1,500p' "$DRY_LOG" || true
echo "=== groqbash --dry-run raw output (end) ==="

DRY_OUT="$(cat "$DRY_LOG" 2>/dev/null || true)"

set -e

if [ $DRY_EXIT -ne 0 ]; then
  echo "  FAIL: --dry-run ha restituito exit code $DRY_EXIT"
  echo "  Output:"
  echo "$DRY_OUT"
  echo
  echo "Suggerimenti diagnostici:"
  echo "- Verifica che il file passato a --json-input sia JSON valido."
  echo "- Per testare stdin, esegui: \"$GROQSH --dry-run <inputfile\""
  echo "- Controlla che TMPDIR sia scrivibile e che mktemp abbia creato i file."
  exit 1
fi

# Trim output and extract JSON
DRY_OUT_TRIMMED="$(printf '%s' "$DRY_OUT" | sed -e 's/^[[:space:]\n\r]*//' -e 's/[[:space:]\n\r]*$//')"
if [ -z "$DRY_OUT_TRIMMED" ]; then
  echo "  FAIL: --dry-run non ha prodotto output"
  exit 1
fi

LINENO="$(printf '%s\n' "$DRY_OUT_TRIMMED" | grep -n -m1 '^[[:space:]]*[{[]' | cut -d: -f1 || true)"
if [ -z "$LINENO" ]; then
  echo "  FAIL: impossibile trovare l'inizio del JSON nell'output"
  echo "  Output completo:"
  echo "$DRY_OUT_TRIMMED"
  exit 1
fi

JSON_ONLY="$(printf '%s\n' "$DRY_OUT_TRIMMED" | tail -n +"$LINENO")"

# Validate JSON
if command -v jq >/dev/null 2>&1; then
  if printf '%s' "$JSON_ONLY" | jq . >/dev/null 2>&1; then
    echo "  OK: --dry-run ha stampato JSON valido (jq)"
  else
    echo "  FAIL: JSON non valido (jq)"
    echo "  Estratto JSON:"
    echo "$JSON_ONLY"
    exit 1
  fi
elif command -v python3 >/dev/null 2>&1; then
  if printf '%s' "$JSON_ONLY" | python3 -c 'import sys,json; json.load(sys.stdin)' >/dev/null 2>&1; then
    echo "  OK: --dry-run ha stampato JSON valido (python3)"
  else
    echo "  FAIL: JSON non valido (python3)"
    echo "  Estratto JSON:"
    echo "$JSON_ONLY"
    exit 1
  fi
else
  first_char="$(printf '%s' "$JSON_ONLY" | sed -n '1p' | sed -e 's/^[[:space:]]*//' -e 's/^\(.\).*/\1/')"
  if [ "$first_char" = "{" ] || [ "$first_char" = "[" ]; then
    echo "  WARNING: jq/python3 non installati; output sembra JSON (heuristic)"
    printf '%s\n' "$JSON_ONLY" | head -n 1
    echo "  OK (heuristic)"
  else
    echo "  FAIL: jq/python3 non disponibili e output non sembra JSON"
    echo "  Estratto JSON:"
    echo "$JSON_ONLY"
    exit 1
  fi
fi

echo
echo "Tutti i test smoke sono passati."
exit 0
