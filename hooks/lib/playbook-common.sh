#!/usr/bin/env bash
# Shared helpers for Playbook hooks. Sourced, never executed directly.

# Resolve the project working directory from hook stdin or PWD.
playbook_project_dir() {
  local cwd
  cwd="$(jq -r '.cwd // empty' 2>/dev/null <<<"${1:-}")"
  [ -n "$cwd" ] && { printf '%s' "$cwd"; return; }
  printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

playbook_dir()        { printf '%s/.playbook' "$(playbook_project_dir "${1:-}")"; }
playbook_anchor()     { printf '%s/anchor.md' "$(playbook_dir "${1:-}")"; }
playbook_ledger()     { printf '%s/uncertainty-ledger.md' "$(playbook_dir "${1:-}")"; }

playbook_ensure_dir() {
  # Only creates the runtime directory. It MUST NOT mutate the consuming
  # project's .gitignore: that is an unsolicited side-effect, races under
  # parallel Stop-hook fire, and is not authorised by design.md. The README
  # documents .playbook/ and the engine proposes the ignore once (Task 11/17),
  # never a per-turn hook.
  mkdir -p "$(playbook_dir "${1:-}")" 2>/dev/null || true
}

# JSON-string escape via bash parameter substitution (single C-level passes;
# identical technique to the Superpowers session-start hook).
playbook_json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"; s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"; s="${s//$'\r'/\\r}"; s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

# Emit the context-injection envelope. Replicates the Superpowers session-start
# 3-platform branch VERBATIM (proven at /tmp/playbook-research/superpowers/hooks/
# session-start lines 46-56, comment 38-45): Claude Code reads BOTH additional_context and the
# nested form without dedup, so exactly one field is emitted per platform.
# Without this branch the overlay+anchor silently never inject on Cursor/Copilot.
playbook_emit_context() {
  local event="${1:-}" body="${2:-}" escaped
  escaped="$(playbook_json_escape "$body")"
  if [ -n "${CURSOR_PLUGIN_ROOT:-}" ]; then
    printf '{\n  "additional_context": "%s"\n}\n' "$escaped"
  elif [ -n "${CLAUDE_PLUGIN_ROOT:-}" ] && [ -z "${COPILOT_CLI:-}" ]; then
    printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "%s",\n    "additionalContext": "%s"\n  }\n}\n' "$event" "$escaped"
  else
    printf '{\n  "additionalContext": "%s"\n}\n' "$escaped"
  fi
}

# Returns the integer percent of the context window USED (0-100), or an empty
# string when the signal is unavailable. Decided in
# docs/playbook/decisions/2026-05-16-context-signal.md.
#
# Source: the GSD-style session-keyed bridge file
#   ${TMPDIR:-/tmp}/claude-ctx-${CLAUDE_CODE_SESSION_ID}.json
# (GSD's gsd-statusline.js writes it; shape:
#  {session_id, remaining_percentage, used_pct, timestamp}). $TMPDIR is honoured
# because GSD's Node os.tmpdir() resolves there on macOS, not /tmp.
#
# CRITICAL: returns percent USED, derived as used = 100 - remaining_percentage.
# GSD keys on remaining; comparing remaining >= 65 would fire at 35% used or
# never. used_pct is only a fallback for a bridge variant lacking remaining.
# No auto-compact-buffer rescale (raw window, matching CC native /context).
#
# Test seam: PLAYBOOK_CTX_FIXTURE, when set, is read instead of the live bridge
# path; it feeds the identical parse path. Silent degradation is mandatory:
# any missing/invalid/unparseable input yields empty, never a wrong number,
# and never aborts a `set -euo pipefail` caller.
playbook_context_percent() {
  {
    local src pct
    if [ -n "${PLAYBOOK_CTX_FIXTURE:-}" ]; then
      src="$PLAYBOOK_CTX_FIXTURE"
    elif [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then
      src="${TMPDIR:-/tmp}/claude-ctx-${CLAUDE_CODE_SESSION_ID}.json"
    else
      printf ''
      return 0
    fi
    [ -f "$src" ] || { printf ''; return 0; }
    # Authoritative path: derive used from remaining_percentage. Fallback to a
    # used field only if remaining is absent/non-numeric. jq emits "" on any
    # failure (missing file, bad JSON, non-numeric), which we treat as unknown.
    pct="$(jq -r '
      if (.remaining_percentage | type) == "number"
        then ((100 - .remaining_percentage) | round)
      elif (.used_pct | type) == "number"
        then (.used_pct | round)
      elif (.used_percentage | type) == "number"
        then (.used_percentage | round)
      else empty end
    ' "$src" 2>/dev/null)" || pct=""
    case "$pct" in
      ''|*[!0-9-]*) printf ''; return 0 ;;
    esac
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    printf '%s' "$pct"
  } 2>/dev/null || true
}

playbook_anchor_init() {
  local original="$1" what_matters="$2" stdin="${3:-}"
  playbook_ensure_dir "$stdin"
  local f; f="$(playbook_anchor "$stdin")"
  [ -f "$f" ] && return 0   # never clobber an existing anchor
  cat >"$f" <<EOF
# Playbook anchor

## Original request (verbatim)
$original

## What matters now (one line)
$what_matters

## Lessons and wrong turns
(none yet)

## Next work
(set by the engine)
EOF
}

playbook_ledger_append() {
  local band="$1" clause="$2" stdin="${3:-}"
  playbook_ensure_dir "$stdin"
  local f ts; f="$(playbook_ledger "$stdin")"
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  printf '%s | %s | %s\n' "$ts" "$band" "$clause" >>"$f"
}

playbook_anchor_read() { local f; f="$(playbook_anchor "${1:-}")"; [ -f "$f" ] && cat "$f" || printf ''; }

# Stop-turn nudge. Channel decided by docs/playbook/decisions/2026-05-16-stop-channel.md.
# MUST be a model-visible, turn-terminating channel (never unconditional decision:block).
playbook_emit_stop_nudge() {
  local body="$1"
  playbook_emit_context "Stop" "$body"   # replace with decided carrier if not additionalContext
}
