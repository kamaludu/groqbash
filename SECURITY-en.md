
[![GroqBash](https://img.shields.io/badge/_GroqBash_-00aa55?style=for-the-badge&label=%E2%9E%9C&labelColor=004d00)](README-en.md)

# SECURITY POLICY &nbsp; [![Italian](https://img.shields.io/badge/IT-Versione_italiana-00aa55?style=flat)](SECURITY.md)

# GroqBash — Security Policy

GroqBash is a single Bash script designed with strong focus on **security**, **portability**, and **auditability**.  
This document describes the **threat model**, **security assumptions**, **known limitations**, **best practices**, and the **responsible disclosure process**.

---

# 1. Supported Versions

| Version | Status |
|---------|--------|
| **1.0.0+** | Supported, receives security updates |
| < 1.0.0 | Unsupported |

Only the latest stable release receives security fixes.

---

# 2. Threat Model

GroqBash is designed for **single‑user environments**, such as:

- personal laptops  
- private servers  
- Termux installations  
- WSL environments  
- local development shells  

GroqBash is **not** designed for:

- multi‑tenant or hostile servers  
- environments where untrusted users can modify the filesystem  
- systems where environment variables can be manipulated by others  
- scenarios requiring strong sandboxing or privilege separation  

## Core Assumptions

GroqBash assumes:

- The user **owns** and **controls** the directories containing GroqBash and its extras.  
- No untrusted user can write to:
  - `$GROQBASHEXTRASDIR`
  - `$GROQBASHTMPDIR`
  - the directory containing `groqbash`
- Environment variables are **trusted configuration**, not untrusted input.  
- Providers are **trusted code**, not plugins from unknown sources.

---

# 3. Security Principles

## ✔ No execution of model output  
GroqBash **never** executes API responses as shell commands.

## ✔ No `eval`  
The script does not use `eval` or equivalent constructs.

## ✔ No use of `/tmp`  
Internal temporary files are **never** created in `/tmp`.  
GroqBash uses:

- `$GROQBASHTMPDIR` (if set)  
- a secure fallback under the user’s home  

Temporary directories are created with:

- `mktemp -d`  
- permissions `700`

## ✔ Hardened provider loading  
Before sourcing a provider, GroqBash checks:

- file existence  
- regular file (not symlink)  
- owner matches current user  
- no group/world write permissions  
- directory not world‑writable  
- TOCTOU mitigation via pre/post checks  

## ✔ No hidden fallbacks  
If the model list is empty, GroqBash fails safely.

## ✔ Minimal dependencies  
Only standard Unix tools are required.  
Optional tools (`jq`, `python3`) improve robustness.

---

# 4. Known Limitations

GroqBash is a Bash script, not a sandboxed runtime.

## ⚠ Residual TOCTOU risks  
Race conditions cannot be fully eliminated in Bash.

## ⚠ Providers are code  
Files in `extras/providers/` are **executed in the shell**.  
They must be:

- owned by the user  
- not writable by others  
- stored in trusted directories  

## ⚠ Environment variables are trusted  
Examples:

- `GROQBASHEXTRASDIR`
- `GROQBASHTMPDIR`
- `GROQ_API_KEY`
- `GROQ_MODEL`

## ⚠ JSON/SSE parsing is best‑effort  
Implemented using `sed`/`awk`/`grep`.  
Robust for normal use, but not a full JSON parser.

## ⚠ No multi‑user isolation  
GroqBash does not attempt to isolate itself from other system users.

---

# 5. Safe Usage Recommendations

## ✔ Keep GroqBash in a directory you own

`CODEON
mkdir -p "$HOME/.local/bin"
CODEOFF`

## ✔ Secure your extras directory

`CODEON
chmod 700 "$GROQBASHEXTRASDIR"
chmod -R go-w "$GROQBASHEXTRASDIR"
CODEOFF`

## ✔ Install providers only from trusted sources  
Providers are shell scripts executed directly.

## ✔ Avoid shared or hostile environments  
GroqBash is not designed for multi‑tenant servers.

## ✔ Use `--debug` only in safe environments  
Debug mode preserves temporary files that may contain sensitive data.

---

# 6. Reporting Vulnerabilities

If you discover a security issue, report it **privately**.

### Private Disclosure Contact
- **Email:** opensource​@​cevangel.​anonaddy.​me  
- **Subject:** `[GroqBash Security Report]`

Include:

- clear description  
- reproduction steps  
- environment details (OS, Bash version, Termux/macOS/etc.)  
- potential impact  

Typical response time: **within 72 hours**.

---

# 7. Responsible Disclosure

- Do not open public issues for vulnerabilities.  
- Do not publish details before a fix is available.  
- Coordinated disclosure is appreciated.  
- Public credit is optional.

---

# 8. Security Extras

GroqBash includes optional tools under `extras/security/`:

- `verify.sh` — provider integrity checks  
- `validate-env.sh` — environment safety checks  

These tools are optional and do not modify core behavior.

---

# 9. Final Notes

GroqBash is built with strong security considerations, but remains a Bash script.  
Users must understand its assumptions and limitations before using it in sensitive environments.

See full documentation:

- **[README](README-en.md)**  
- **[INSTALL](INSTALL.md)**  
- **[CHANGELOG](CHANGELOG.md)**
