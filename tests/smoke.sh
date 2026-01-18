#!/usr/bin/env bash
# Smoke test minimale per GroqShell
# Verifica che ./bin/groqshell --version e --dry-run funzionino correttamente.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/bin/groqshell"

if [ ! -x "$SCRIPT" ]; then
  echo "ERRORE: $SCRIPT non trovato o non eseguibile."
  exit 2
fi

echo "Eseguo smoke test su: $SCRIPT"
echo

echo "1) Verifica --version"
if "$SCRIPT" --version >/dev/null 2>&1; then
  echo "  OK: --version eseguito"
else
  echo "  FAIL: --version ha fallito"
  exit 3
fi

echo
echo "2) Verifica --dry-run (payload JSON)"
# Usa un prompt semplice; non richiede GROQ_API_KEY perché --dry-run non invia la richiesta
if "$SCRIPT" --dry-run "test smoke" >/dev/null 2>&1; then
  echo "  OK: --dry-run eseguito"
else
  echo "  FAIL: --dry-run ha fallito"
  exit 4
fi

echo
echo "Smoke test completato con successo."
exit 0
