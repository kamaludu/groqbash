[![GroqBash](https://img.shields.io/badge/_GroqBash_-00aa55?style=for-the-badge&label=%E2%9E%9C&labelColor=004d00)](README.md)

# SECURITY POLICY &nbsp; [![Italian](https://img.shields.io/badge/IT-Versione_italiana-00aa55?style=flat)](SECURITY.md) 

# GroqBash — Security Policy

GroqBash is a single‑file Bash wrapper for the Groq API, designed with a strong focus on safety, portability, and transparency.  
This document describes the project’s **security model**, **expected usage**, **known limitations**, and **responsible disclosure process**.

---

# 1. Supported Versions

GroqBash follows a simple support model:

| Version | Status |
|--------|--------|
| **1.0.0+** | Supported, receives security updates |
| < 1.0.0 | Not supported |

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

- multi‑tenant or hostile shared servers  
- environments where untrusted users can modify your filesystem  
- systems where environment variables can be manipulated by attackers  
- scenarios requiring strong sandboxing or privilege separation  

### Core assumptions

GroqBash assumes:

- The user **owns** and **controls** the directories where GroqBash and its extras are stored.  
- No untrusted user can write to:
  - `$GROQBASHEXTRASDIR`
  - `$GROQBASHTMPDIR`
  - the directory containing `groqbash`
- Environment variables are **trusted configuration**, not untrusted input.
- Provider modules are **trusted code**, not plugins from unknown sources.

---

# 3. Security Design Principles

GroqBash follows these principles:

### ✔ No execution of model output  
GroqBash **never** executes API responses as shell commands.

### ✔ No `eval`  
The script does not use `eval` or similar dynamic execution constructs.

### ✔ No `/tmp` usage  
Internal temporary files are **never** placed in `/tmp`.  
GroqBash uses:

- `$GROQBASHTMPDIR` (if set)  
- a secure fallback under the user’s home  

Temporary directories are created with:

- `mktemp -d`
- permissions `700`

### ✔ Provider hardening  
Before sourcing a provider module, GroqBash checks:

- file exists  
- file is a regular file  
- file is not a symlink  
- owner matches the current user  
- no group/world write permissions  
- directory is not world‑writable  
- minimal TOCTOU mitigation via pre/post metadata checks  

### ✔ No hidden fallbacks  
Model selection is explicit and validated.  
If the model list is empty, GroqBash fails safely.

### ✔ Minimal external dependencies  
Only standard Unix tools are required.  
Optional tools (`jq`, `python3`) improve robustness but are not required.

---

# 4. Known Limitations

GroqBash is a Bash script, not a sandboxed runtime.  
The following limitations are inherent and expected:

### ⚠ Residual TOCTOU risks  
File checks and sourcing occur sequentially; Bash cannot eliminate TOCTOU entirely.

### ⚠ Provider modules are code  
Files under `extras/providers/` are **executed in your shell**.  
They must be:

- owned by you  
- not writable by others  
- stored in trusted directories  

### ⚠ Environment variables are trusted  
Variables such as:

- `GROQBASHEXTRASDIR`
- `GROQBASHTMPDIR`
- `GROQ_API_KEY`
- `GROQ_MODEL`

are treated as trusted configuration.

### ⚠ JSON/SSE parsing is best‑effort  
GroqBash uses `sed`/`awk`/`grep` for parsing.  
This is robust for normal use but not equivalent to a full JSON parser.

### ⚠ No multi‑user isolation  
GroqBash does not attempt to isolate itself from other users on the same system.

---

# 5. Recommendations for Safe Usage

To ensure secure operation:

### ✔ Keep GroqBash in a directory owned by you  
Example:

`sh
mkdir -p "$HOME/.local/bin"
`

### ✔ Ensure extras directories are safe

`sh
chmod 700 "$GROQBASHEXTRASDIR"
chmod -R go-w "$GROQBASHEXTRASDIR"
`

### ✔ Never install provider modules from untrusted sources  
Provider modules are shell scripts executed directly.

### ✔ Avoid running GroqBash on shared or hostile systems  
GroqBash is not designed for multi‑tenant environments.

### ✔ Use `--debug` only in trusted contexts  
Debug mode preserves temporary files, which may contain sensitive data.

---

# 6. Reporting a Vulnerability

If you discover a security issue, please report it privately.

### Contact (private disclosure)
- **Email:** opensource​@​cevangel.​anonaddy.​me  
- **Subject:** `[GroqBash Security Report]`

Please include:

- a clear description of the issue  
- steps to reproduce  
- environment details (OS, Bash version, Termux/macOS/etc.)  
- whether the issue allows code execution, privilege escalation, or data exposure  

We aim to acknowledge reports within **72 hours**.

---

# 7. Responsible Disclosure Policy

- Do **not** open public GitHub issues for security vulnerabilities.  
- Do **not** publish details before a fix is released.  
- Coordinated disclosure is appreciated.  
- Credit will be given to reporters unless anonymity is requested.

---

# 8. Security Extras

GroqBash includes optional tools under `extras/security/`:

- `verify.sh` — checks provider integrity (permissions, owner, symlink, checksum)  
- `validate-env.sh` — validates environment variables and directory safety  

These tools are **optional** and do not modify core behavior.

---

# 9. Final Notes

GroqBash is built with a strong focus on safety, but it remains a Bash script.  
Users should understand its assumptions and limitations before deploying it in sensitive environments.

For full documentation, see:

- **README.md**  
- **INSTALL.md**  
- **CHANGELOG.md**
