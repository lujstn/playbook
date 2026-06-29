#!/usr/bin/env bash
# Tests for the ntfy notify seam: the new helpers in playbook-common.sh
# (playbook_ntfy_topic, playbook_ntfy_server, playbook_remote_url,
# playbook_latest_transcript) and the integration of scripts/notify against
# a curl stub. Every test pins one specific behaviour the production path
# relies on: the remote-control URL must be recoverable, must be immune to
# user-channel paste poisoning, must be gated on the bridge being active,
# and the script must degrade visibly (documented exit codes) when the
# topic, the server or curl is absent.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$root/hooks/lib/playbook-common.sh"

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT

# --- unit: helpers --------------------------------------------------------

proj="$sandbox/proj"
mkdir -p "$proj/.claude/playbook"

# Topic + server read with whitespace trimming.
printf '  topic-abc  \n' > "$proj/.claude/playbook/ntfy-topic"
printf 'https://ntfy.example.com\n'  > "$proj/.claude/playbook/ntfy-server"
[ "$(playbook_ntfy_topic "$proj")" = "topic-abc" ] \
  && echo "PASS: ntfy-topic read and trimmed" \
  || { echo "FAIL: topic was [$(playbook_ntfy_topic "$proj")]"; exit 1; }
[ "$(playbook_ntfy_server "$proj")" = "https://ntfy.example.com" ] \
  && echo "PASS: ntfy-server override read" \
  || { echo "FAIL: server was [$(playbook_ntfy_server "$proj")]"; exit 1; }

# Missing topic/server files: empty, never a wrong value.
empty_proj="$sandbox/empty"
mkdir -p "$empty_proj"
[ -z "$(playbook_ntfy_topic  "$empty_proj")" ] \
  && echo "PASS: missing topic file yields empty" \
  || { echo "FAIL: missing topic file did not yield empty"; exit 1; }
[ -z "$(playbook_ntfy_server "$empty_proj")" ] \
  && echo "PASS: missing server file yields empty" \
  || { echo "FAIL: missing server file did not yield empty"; exit 1; }

# Remote URL recovery from the active fixture, ignoring the user paste.
ACTIVE_FIX="$root/tests/hooks/fixtures/transcript-bridge.jsonl"
url_active="$(playbook_remote_url "$ACTIVE_FIX")"
[ "$url_active" = "https://claude.ai/code/session_TEST_ACTIVE" ] \
  && echo "PASS: active bridge_status url recovered, user paste ignored" \
  || { echo "FAIL: url_active was [$url_active]"; exit 1; }

# Inactive bridge_status: gating keeps the URL empty.
INACTIVE_FIX="$root/tests/hooks/fixtures/transcript-bridge-inactive.jsonl"
url_inactive="$(playbook_remote_url "$INACTIVE_FIX")"
[ -z "$url_inactive" ] \
  && echo "PASS: inactive bridge_status yields no url" \
  || { echo "FAIL: url_inactive was [$url_inactive]"; exit 1; }

# Paste-only transcript (no bridge_status record at all): empty.
PASTE_ONLY="$sandbox/paste-only.jsonl"
printf '%s\n' '{"type":"user","message":{"role":"user","content":"see https://claude.ai/code/session_PASTE_ONLY here"}}' > "$PASTE_ONLY"
url_paste="$(playbook_remote_url "$PASTE_ONLY")"
[ -z "$url_paste" ] \
  && echo "PASS: user paste alone cannot match the bridge_status filter" \
  || { echo "FAIL: url_paste was [$url_paste]"; exit 1; }

# latest_transcript: encodes the project dir under HOME and picks the most
# recent jsonl. Sandbox HOME so the test cannot stomp on the real one.
fake_home="$sandbox/home"
enc="$(printf '%s' "$proj" | tr '/' '-')"
mkdir -p "$fake_home/.claude/projects/$enc"
cp "$ACTIVE_FIX" "$fake_home/.claude/projects/$enc/session.jsonl"
found="$(HOME="$fake_home" playbook_latest_transcript "$proj")"
[ "$found" = "$fake_home/.claude/projects/$enc/session.jsonl" ] \
  && echo "PASS: latest transcript discovered under encoded project path" \
  || { echo "FAIL: latest_transcript was [$found]"; exit 1; }
nothing="$(HOME="$sandbox/empty-home" playbook_latest_transcript "$proj")"
[ -z "$nothing" ] \
  && echo "PASS: empty when the encoded transcript dir does not exist" \
  || { echo "FAIL: latest_transcript with no dir was [$nothing]"; exit 1; }

# --- integration: scripts/notify with a curl stub -------------------------

# Stub curl: captures args to log file; outputs {"status":1} for Pushover
# response parsing; exits 0. Sandboxed by PATH override.
stub_bin="$sandbox/bin"
mkdir -p "$stub_bin"
cat >"$stub_bin/curl" <<'STUB'
#!/usr/bin/env bash
log="${CURL_LOG:-/dev/null}"
{
  echo "ARGS:"
  for a in "$@"; do printf '  %s\n' "$a"; done
} >"$log"
printf '{"status":1}'
exit 0
STUB
chmod +x "$stub_bin/curl"

# Real PATH plus the stub-bin prefix so curl resolves to the stub, jq/awk/etc
# stay reachable. CURL_LOG captures one request per invocation.
NOTIFY="$root/scripts/notify"
LOG="$sandbox/curl.log"
run_notify() {
  CURL_LOG="$LOG" HOME="$fake_home" PATH="$stub_bin:$PATH" \
    bash -c "cd '$proj' && '$NOTIFY' \"\$@\"" -- "$@"
}

# Restore ntfy config: provider file, topic, and server override.
printf 'ntfy\n' > "$proj/.claude/playbook/notify-provider"
cp "$ACTIVE_FIX" "$fake_home/.claude/projects/$enc/session.jsonl"

# Usage errors degrade with documented exits.
set +e
run_notify >/dev/null 2>&1; ec=$?; set -e
[ "$ec" -eq 64 ] && echo "PASS: no-args yields exit 64 (usage)" \
  || { echo "FAIL: no-args exit was $ec"; exit 1; }
set +e
run_notify --category=weird "hello" >/dev/null 2>&1; ec=$?; set -e
[ "$ec" -eq 64 ] && echo "PASS: unknown category yields exit 64" \
  || { echo "FAIL: bad category exit was $ec"; exit 1; }

# Missing topic: documented exit 4.
mv "$proj/.claude/playbook/ntfy-topic" "$sandbox/topic.bak"
set +e
run_notify "hello" >/dev/null 2>&1; ec=$?; set -e
[ "$ec" -eq 4 ] && echo "PASS: missing topic yields exit 4" \
  || { echo "FAIL: no-topic exit was $ec"; exit 1; }
mv "$sandbox/topic.bak" "$proj/.claude/playbook/ntfy-topic"

# Missing curl: documented exit 5.
nocurl_bin="$sandbox/nocurl_bin"
mkdir -p "$nocurl_bin"
for tool in bash dirname basename env tr awk sed jq ls grep cat tail head printf mktemp; do
  src="$(command -v "$tool" 2>/dev/null || true)"
  [ -n "$src" ] && ln -sf "$src" "$nocurl_bin/$tool"
done
set +e
CURL_LOG="$LOG" HOME="$fake_home" PATH="$nocurl_bin" \
  bash -c "cd '$proj' && '$NOTIFY' 'hello'" >/dev/null 2>&1
ec=$?
set -e
[ "$ec" -eq 5 ] && echo "PASS: missing curl yields exit 5" \
  || { echo "FAIL: no-curl exit was $ec"; exit 1; }

# Default level is info: no --level flag -> Priority 3, "Info:" title prefix.
rm -f "$LOG"
run_notify "Schema decision" "NOT NULL backfill needs your call"
grep -qx '  Title: 📚 Info: Schema decision' "$LOG" \
  && echo "PASS: default level is info, title prefix Info:" \
  || { echo "FAIL: default-level title missing in [$(cat "$LOG")]"; exit 1; }
grep -qx '  Priority: 3' "$LOG" \
  && echo "PASS: default level info maps to ntfy Priority 3" \
  || { echo "FAIL: default-level priority wrong in [$(cat "$LOG")]"; exit 1; }
grep -qx '  NOT NULL backfill needs your call' "$LOG" \
  && echo "PASS: body = detail when detail supplied" \
  || { echo "FAIL: body argument wrong in [$(cat "$LOG")]"; exit 1; }
grep -qx '  Click: https://claude.ai/code/session_TEST_ACTIVE' "$LOG" \
  && echo "PASS: Click header carries the recovered active session URL" \
  || { echo "FAIL: Click header missing/wrong in [$(cat "$LOG")]"; exit 1; }
grep -qx '  https://ntfy.example.com/topic-abc' "$LOG" \
  && echo "PASS: URL = server override / topic" \
  || { echo "FAIL: target URL wrong in [$(cat "$LOG")]"; exit 1; }

# --level action: Priority 4, "Action:" title prefix.
rm -f "$LOG"
run_notify --level action "Deploy failed" "ci/cd pipeline exited non-zero"
grep -qx '  Title: 📚 Action: Deploy failed' "$LOG" \
  && echo "PASS: --level action title prefix Action:" \
  || { echo "FAIL: action title wrong in [$(cat "$LOG")]"; exit 1; }
grep -qx '  Priority: 4' "$LOG" \
  && echo "PASS: --level action maps to ntfy Priority 4" \
  || { echo "FAIL: action priority wrong in [$(cat "$LOG")]"; exit 1; }

# --level critical: Priority 5, "Critical:" title prefix.
rm -f "$LOG"
run_notify --level critical "System down"
grep -qx '  Title: 📚 Critical: System down' "$LOG" \
  && echo "PASS: --level critical title prefix Critical:" \
  || { echo "FAIL: critical title wrong in [$(cat "$LOG")]"; exit 1; }
grep -qx '  Priority: 5' "$LOG" \
  && echo "PASS: --level critical maps to ntfy Priority 5" \
  || { echo "FAIL: critical priority wrong in [$(cat "$LOG")]"; exit 1; }

# --category=action back-compat: same as --level action.
rm -f "$LOG"
run_notify --category=action "Wave merged"
grep -qx '  Title: 📚 Action: Wave merged' "$LOG" \
  && echo "PASS: --category=action back-compat works" \
  || { echo "FAIL: category=action back-compat title wrong in [$(cat "$LOG")]"; exit 1; }
grep -qx '  Priority: 4' "$LOG" \
  && echo "PASS: --category=action back-compat maps to Priority 4" \
  || { echo "FAIL: category=action back-compat priority wrong in [$(cat "$LOG")]"; exit 1; }

# --category=info back-compat: default priority, info title prefix, body =
# headline when no detail arg.
rm -f "$LOG"
run_notify --category=info "Wave 2 merged"
grep -qx '  Title: 📚 Info: Wave 2 merged' "$LOG" \
  && echo "PASS: --category=info back-compat renders Info: title" \
  || { echo "FAIL: category=info title wrong in [$(cat "$LOG")]"; exit 1; }
grep -qx '  Priority: 3' "$LOG" \
  && echo "PASS: --category=info back-compat maps to Priority 3" \
  || { echo "FAIL: category=info priority wrong in [$(cat "$LOG")]"; exit 1; }
grep -qx '  Wave 2 merged' "$LOG" \
  && echo "PASS: body = headline when detail omitted" \
  || { echo "FAIL: body fallback wrong in [$(cat "$LOG")]"; exit 1; }

# --link overrides the remote-control URL.
rm -f "$LOG"
run_notify --link https://example.com/pr/42 "PR review needed"
grep -qx '  Click: https://example.com/pr/42' "$LOG" \
  && echo "PASS: --link overrides the session URL in Click header" \
  || { echo "FAIL: --link override wrong in [$(cat "$LOG")]"; exit 1; }

# Inactive bridge_status: no Click header when not overridden by --link.
cp "$INACTIVE_FIX" "$fake_home/.claude/projects/$enc/session.jsonl"
rm -f "$LOG"
run_notify "Heads up"
grep -q 'Click:' "$LOG" \
  && { echo "FAIL: Click header should be absent when bridge is inactive"; cat "$LOG"; exit 1; } \
  || echo "PASS: no Click header when bridge_status is inactive"

# Default server when no override is configured.
rm -f "$proj/.claude/playbook/ntfy-server"
rm -f "$LOG"
run_notify "ping"
grep -qx '  https://ntfy.sh/topic-abc' "$LOG" \
  && echo "PASS: default server (https://ntfy.sh) used when no override" \
  || { echo "FAIL: default server wrong in [$(cat "$LOG")]"; exit 1; }

# --- Pushover provider tests -----------------------------------------------

# Switch to Pushover: set provider + credentials.
printf 'pushover\n' > "$proj/.claude/playbook/notify-provider"
printf 'token_abc\n' > "$proj/.claude/playbook/pushover-token"
printf 'user_xyz\n' > "$proj/.claude/playbook/pushover-user"
cp "$ACTIVE_FIX" "$fake_home/.claude/projects/$enc/session.jsonl"

# --level info: Pushover priority 0, "Info:" title.
rm -f "$LOG"
run_notify --level info "Heads up"
grep -qx '  --form-string' "$LOG" \
  && echo "PASS: Pushover form-string args present" \
  || { echo "FAIL: Pushover args missing in [$(cat "$LOG")]"; exit 1; }
grep -q 'title=📚 Info: Heads up' "$LOG" \
  && echo "PASS: Pushover info title rendered" \
  || { echo "FAIL: Pushover info title wrong in [$(cat "$LOG")]"; exit 1; }
grep -q 'priority=0' "$LOG" \
  && echo "PASS: Pushover info maps to priority 0" \
  || { echo "FAIL: Pushover info priority wrong in [$(cat "$LOG")]"; exit 1; }

# --level action: Pushover priority 1.
rm -f "$LOG"
run_notify --level action "Need your call"
grep -q 'priority=1' "$LOG" \
  && echo "PASS: Pushover action maps to priority 1" \
  || { echo "FAIL: Pushover action priority wrong in [$(cat "$LOG")]"; exit 1; }
grep -q 'title=📚 Action: Need your call' "$LOG" \
  && echo "PASS: Pushover action title rendered" \
  || { echo "FAIL: Pushover action title wrong in [$(cat "$LOG")]"; exit 1; }

# --level critical: Pushover priority 2 with retry, expire, and sound=siren.
rm -f "$LOG"
run_notify --level critical "Emergency"
grep -q 'priority=2' "$LOG" \
  && echo "PASS: Pushover critical maps to priority 2" \
  || { echo "FAIL: Pushover critical priority wrong in [$(cat "$LOG")]"; exit 1; }
grep -q 'retry=60' "$LOG" \
  && echo "PASS: Pushover critical adds retry=60" \
  || { echo "FAIL: Pushover critical missing retry in [$(cat "$LOG")]"; exit 1; }
grep -q 'expire=1800' "$LOG" \
  && echo "PASS: Pushover critical adds expire=1800" \
  || { echo "FAIL: Pushover critical missing expire in [$(cat "$LOG")]"; exit 1; }
grep -q 'sound=siren' "$LOG" \
  && echo "PASS: Pushover critical adds sound=siren" \
  || { echo "FAIL: Pushover critical missing sound in [$(cat "$LOG")]"; exit 1; }

# --link attaches url field on Pushover.
rm -f "$LOG"
run_notify --link https://example.com/pr/42 --level action "Review needed"
grep -q 'url=https://example.com/pr/42' "$LOG" \
  && echo "PASS: Pushover --link attaches url field" \
  || { echo "FAIL: Pushover --link url missing in [$(cat "$LOG")]"; exit 1; }

# Missing Pushover credentials -> exit 4.
rm "$proj/.claude/playbook/pushover-token"
set +e
run_notify "test" >/dev/null 2>&1; ec=$?; set -e
[ "$ec" -eq 4 ] && echo "PASS: missing Pushover token yields exit 4" \
  || { echo "FAIL: missing token exit was $ec"; exit 1; }

# No provider configured and no ntfy-topic fallback -> exit 4.
rm "$proj/.claude/playbook/notify-provider"
rm -f "$proj/.claude/playbook/ntfy-topic"
set +e
run_notify "test" >/dev/null 2>&1; ec=$?; set -e
[ "$ec" -eq 4 ] && echo "PASS: no provider configured yields exit 4" \
  || { echo "FAIL: no-provider exit was $ec"; exit 1; }
