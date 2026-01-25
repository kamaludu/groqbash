#!/usr/bin/env bash
# =============================================================================
# GroqBash — Bash-first wrapper for the Groq API
# File: extras/docs/core-notes.sh
# Copyright (C) 2026 Cristian Evangelisti
# License: GPL-3.0-or-later
# Source: https://github.com/<your-repo>/groqbash
# =============================================================================
# Purpose: Extended design notes and operational guidance for groqbash core.
# This is documentation intended to be sourced or read by humans; it does not
# alter runtime behavior when sourced. Keep it optional and read-only.

: <<'DOC'
groqbash — Core Notes
=====================

Overview
--------
groqbash is intentionally Groq-first: the core implements only the Groq provider
(endpoint, payload builder, streaming parser, and request orchestration).  All
non-core providers (e.g., Gemini) live under extras/providers/ and are loaded
on demand by the core when PROVIDER != "groq".

This split keeps the core small, auditable, and stable while allowing provider
extensions to be developed independently.

Provider architecture
---------------------
- SUPPORTED_PROVIDERS (declared in core) lists known providers for UI/help.
- PROVIDER defaults to "groq". The core reads groqbash.d/config/provider (first
  line) if present to override the default.
- CLI override: `--provider <name>` sets PROVIDER for the current run and saves
  it to groqbash.d/config/provider.
- Interactive selection: `--provider` (no arg) or `--provider list` shows a
  numbered menu, lets the user pick a provider, saves it, and triggers a
  provider-aware refresh-models.

Provider modules (extras/providers/<provider>.sh)
- Each module must define:
    build_payload_<provider>()
    call_api_<provider>()
    call_api_streaming_<provider>()
  The core dispatchers call these functions when PROVIDER != "groq".
- Modules are optional. If a module is missing, the core prints:
    Provider '<provider>' is not installed. Run --install-extras.
  and exits non-zero.

Model precedence (final model selection)
----------------------------------------
When the script decides which MODEL to use for a request, the precedence is:

  1) CLI: `--model <name>` (highest precedence for this execution)
  2) Per-provider config: groqbash.d/config/model.$PROVIDER (first non-empty line)
  3) Dynamic default: derived from groqbash.d/models/<provider>.json
     - The dynamic default is chosen deterministically:
       * Prefer models marked both "recommended" and "chat-capable"
       * Else prefer models marked "chat-capable"
       * Else pick the first model listed
     - If the file is missing, empty, or malformed, fall back to (4)
  4) Previous fallback logic:
     - GROQ_MODEL environment variable
     - groqbash.d/config MODEL= entry
     - auto_select_model() (whitelist-based heuristic)

Dynamic default logic
---------------------
- The core provides choose_dynamic_model_from_file() which reads the provider's
  models file (written by refresh_models) and applies the heuristic above.
- The function is robust: it never aborts the script on parse errors; it simply
  returns an empty string so the fallback chain continues.

refresh-models behavior
-----------------------
- refresh_models() calls the Groq models endpoint (Groq-only).
- It parses the returned JSON for model IDs and writes them to a file.
- When invoked with an explicit path, refresh_models writes to that path,
  enabling provider-aware model files (e.g., groqbash.d/models/gemini.json).
- The core does not add non-Groq endpoints in refresh_models.

Streaming behavior
------------------
- Groq streaming uses SSE-like fragments. The core's streaming parser:
  - Reads lines from curl output.
  - Handles `data: [DONE]` or `data:[DONE]` as stream termination.
  - Extracts `"content"` fields from JSON fragments (best-effort).
  - Applies a minimal, safe unescape sequence:
      1) `\"` -> `"`
      2) `\\` -> `\`
      3) `\/` -> `/`
    plus a final best-effort cleanup to remove wrapping backslashes in some
    streaming fragments.
  - Prints chunks progressively to stdout.
- The parser is intentionally conservative to avoid over‑interpreting partial
  JSON fragments.

Rationale for Groq-first core
-----------------------------
- Security and auditability: keeping the core minimal reduces the surface area
  for bugs and makes it easier to review.
- Stability: Groq is the only fully implemented provider in the core; other
  providers are optional modules that can evolve independently.
- Extensibility: provider modules can be added/removed without touching the
  core; the loader contract is simple and explicit.

Operational tips
----------------
- To add a provider:
  1) Create extras/providers/<provider>.sh implementing the three functions.
  2) Ensure the module checks for required env vars (API keys) and fails
     clearly if missing.
  3) The module should not redefine core functions or change global state.

- To debug model selection:
  * Check groqbash.d/config/model.<provider>
  * Check groqbash.d/models/<provider>.json (refresh with --refresh-models)
  * Check GROQ_MODEL env and groqbash.d/config MODEL= entries

- To keep the core minimal, place optional helpers and diagnostics under
  extras/lib/ and source them only when needed.

DOC
