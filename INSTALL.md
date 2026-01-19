# Installazione rapida

Prerequisiti:
- bash
- curl
- opzionale: jq, python3

Installazione:
1. Scarica lo script:
curl -O https://raw.githubusercontent.com/kamaludu/groqshell/main/bin/groqshell

2. Rendi eseguibile:
   chmod +x bin/groqshell
3. Esporta la API key:
   export GROQ_API_KEY="gsk_..."
4. Test:
   ./bin/groqshell --version
