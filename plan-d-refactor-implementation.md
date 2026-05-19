# Persistence and Unease Refactor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Playbook's rejected on-disk persistence (`.playbook/` anchor and ledger files, GSD context bridge) with the in-session, no-file design specified in `plan-c-refactor.md`.

**Architecture:** The conversation is the store. Hooks recover the original request from the transcript (`transcript_path` in hook stdin), steer the compaction seam, and prompt a per-action unease pulse; they never write a file into the user's tree. The context signal is the transcript usage sum over an agent-declared window. Tenets 1, 4 and 7 stay separate mechanisms on shared plumbing.

**Tech Stack:** Bash hooks, `jq`, the existing `tests/` shell harness (`tests/run-all.sh`, `tests/manifests.sh`, `tests/hooks/*.sh`), Claude Code hook JSON contract.

**Authority:** `plan-c-refactor.md` is the committed source of truth. Sections cited below (for example "plan-c §3") refer to its authored sections 0 to 13; Annex 2 is the binding unease specification. Where this plan gives exact replacement text, that text governs; where it gives a transformation rule, apply it faithfully to the cited spec. All absolute line numbers in this plan are approximate, pre-edit references for orientation only; intra-task edits shift them, so the authoritative anchors are always the quoted verbatim old-text and the grep assertions, never the line numbers.

**Binding constraints (every task):** British English. Zero long dashes (no U+2014, no U+2013) in any shipped or spec file. The concept is `unease`, never `uncertainty` or `anxiety`, except where naming an old artefact being removed. No pestering or repetitive-prompting behaviour. No file is written into the user's working tree. `plan-a-design.md` receives only the sanctioned section 11 edits, applied seamlessly so it reads as though always written that way.

**Commit rule:** one commit per task, message in British English, no `Co-Authored-By` line, on branch `build-playbook-plugin`.

**Deviation D1 (errexit jq guard, applied during execution):** The Task 2 `unease` and Task 3 `take-a-beat` hook bodies as first drafted ran `event="$(jq ... <<<"$stdin")"` (and the Task 3 `src="$(jq ...)"`) with no failure guard. Under `set -euo pipefail` a non-JSON or truncated stdin makes that command substitution non-zero and aborts the hook before the `event="Stop"`/empty fallback can run, so the hook emits nothing and exits with an error. That silently disables the tenet on that turn and contradicts plan-c's mandatory silent-degradation contract. The sanctioned correction, recorded here so the text reads as though always written this way, is the trailing `|| true` on those `jq` substitutions plus an empty-and-non-JSON-stdin regression assertion in the Task 2 and Task 3 tests. Behaviour for every valid hook JSON payload is unchanged.

**Deviation D2 (full verbatim original-request recovery, applied during execution):** Task 1's `playbook_original_request` as first drafted ended its pipeline with `awk 'NF{print; exit}'`, returning only the first non-empty line of the first human message, so a multi-paragraph original request was truncated to a single line. That defeats Tenet 1's verbatim recovery, the reason the no-file design exists, and stays green against single-line fixtures, the same silent class as D1. The sanctioned correction, recorded here so the text reads as though always written this way, replaces the streaming `jq -r ... | awk` with a slurped `jq -rs` that selects the first genuine human message (skipping system and hook records and tool-result turns) and emits its complete content with multi-line preserved, plus a multi-line fixture and an assertion proving full verbatim recovery. Behaviour for single-line requests is unchanged.

**Deviation D3 (section-8 ledger-gate residue, applied during execution):** Task 9 Step 4 scopes "the section 8 ... references" to the ledger, but the escalation-ladder step 7 clause `having consulted the external manager first where the ledger warrants` first survived the rewrite: Step 3 renames only `uncertainty ledger`→`unease ledger`, so a phrase that already read bare `the ledger` was never renamed, and the Step 1 assertion `unease ledger|the unease ledger` could not catch it. That left section 8 self-contradicting (step 6 "gated by the unease sense" versus step 7 "where the ledger warrants"), contradicting the new section 6 "no ledger", and disagreeing with the already-shipped `offline-mode/SKILL.md` whose byte-identical sibling Task 7 converted to "where your in-session unease warrants". The sanctioned correction, recorded here so the text reads as though always written this way, converts that step-7 clause to `where your in-session unease warrants` and adds a Step 1 assertion that catches any surviving positive ledger-gate phrasing without tripping the legitimate offline decision-log noun.

**Deviation D4 (aggregate long-dash sweep silently false-green on BSD grep, applied during execution):** Task 10 Step 2 first mandated the aggregate sweep detector `LC_ALL=C grep -rln $'\xe2\x80\x94\|\xe2\x80\x93'`, asserting it matches on both BSD and GNU grep. Empirically it does not: under BSD grep, the primary dev platform, with a C locale, the BRE `\|` alternation over multibyte byte-operands silently fails to match, so the gate stays green even when a long dash is present. That is exactly the silent-no-op class this gate exists to eliminate, one layer deeper than the original `grep -rlnP` it replaced, and the project memory's blessed recursive form was itself this unsound construct. The sanctioned correction, recorded here so the text reads as though always written this way, splits the single fragile alternation into two single-codepoint byte scans combined by shell `||` (no `\|` operand), proven sound on BSD grep under both a C and a UTF-8 locale and on GNU grep, with the FAIL and success polarity and message unchanged.

**Retained, not deleted:** `plan-b-implementation.md` is the superseded build plan for the rejected model. Per `plan-c-refactor.md` section 0 this plan supersedes it; it stays in the repository as historical record, like `archived-docs-for-context/`, and no task removes it.

---

## File structure

| File | Responsibility after refactor |
|---|---|
| `hooks/lib/playbook-common.sh` | Cross-platform emitter (kept); new transcript reader, original-request recovery, usage-sum, declared-window and context-percent helpers; the eight file/GSD helpers removed |
| `hooks/unease` (was `hooks/uncertainty`) | One stateless constant-prompt hook on `PostToolUse` and `Stop` |
| `hooks/take-a-beat` | Compaction seam (recover original request from transcript, re-inject with primacy) plus the transcript-derived context beat |
| `hooks/session-start` | Overlay digest stating the in-session no-file model |
| `hooks/hooks.json` | Event wiring for the renamed and rewired hooks |
| `skills/playbook/SKILL.md` | Tenet 1, 4, 7 doctrine in the in-session model; rejected-model artefacts and stale cross-references removed |
| `skills/offline-mode/SKILL.md` | Ledger references converted to the no-ledger unease model; behaviour unchanged |
| `plan-a-design.md` | Sanctioned section 11 edits only |
| `README.md` | Runtime-state and tenet/hook prose rewritten to the no-file model |
| `.gitignore` | The `.playbook/` vestige removed |
| `tests/hooks/*.sh`, `tests/run-all.sh`, `tests/hooks/fixtures/*` | Suite rewritten to the new model, brought green |

Task order is dependency-ordered: helpers first (everything depends on them), then the hooks, then wiring, then doctrine and docs, then the suite cleanup, then the live-only verification block.

---

### Task 1: Helper refactor in `hooks/lib/playbook-common.sh`

**Files:**
- Modify: `hooks/lib/playbook-common.sh`
- Create: `tests/hooks/fixtures/transcript-basic.jsonl`
- Create: `tests/hooks/fixtures/transcript-beat.jsonl`
- Create: `tests/hooks/test-helpers.sh`

- [ ] **Step 1: Write the transcript fixtures**

Create `tests/hooks/fixtures/transcript-basic.jsonl` (a minimal Claude Code transcript: a system-injected first record, then the genuine first human message, then an assistant turn with a `usage` block, then a later assistant turn whose usage sums to a known total, plus a declared-window line in an assistant turn):

```jsonl
{"type":"system","subtype":"hook","content":"SessionStart hook additional context: noise"}
{"type":"user","message":{"role":"user","content":"Build me a widget that does X. Original request text."}}
{"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":10,"cache_creation_input_tokens":1000,"cache_read_input_tokens":4000,"output_tokens":50},"content":[{"type":"text","text":"playbook-window: 1000000"}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"some tool output"}]}}
{"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":20,"cache_creation_input_tokens":2000,"cache_read_input_tokens":8000,"output_tokens":99},"content":[{"type":"text","text":"working"}]}}
```

Create `tests/hooks/fixtures/transcript-beat.jsonl` (last usage sums to 700020 of a declared 1,000,000 window, i.e. 70 percent used):

```jsonl
{"type":"user","message":{"role":"user","content":"Beat fixture original request."}}
{"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","usage":{"input_tokens":20,"cache_creation_input_tokens":120000,"cache_read_input_tokens":580000,"output_tokens":10},"content":[{"type":"text","text":"playbook-window: 1000000"}]}}
```

Create `tests/hooks/fixtures/transcript-multiline.jsonl` (a system record, then a genuine first human message whose content is a multi-line string, then a later tool-result user turn that must be skipped, proving the recovery returns the complete first human message verbatim and not a later turn):

```jsonl
{"type":"system","subtype":"hook","content":"noise"}
{"type":"user","message":{"role":"user","content":"First paragraph of the ask.\nSecond paragraph with detail.\nThird line."}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"tool noise"}]}}
{"type":"assistant","message":{"role":"assistant","model":"claude-opus-4-7","content":[{"type":"text","text":"ok"}]}}
```

- [ ] **Step 2: Write the failing helper test**

Create `tests/hooks/test-helpers.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
source "$root/hooks/lib/playbook-common.sh"
B="$root/tests/hooks/fixtures/transcript-basic.jsonl"
T="$root/tests/hooks/fixtures/transcript-beat.jsonl"
stdin_b="$(printf '{"transcript_path":"%s"}' "$B")"
stdin_t="$(printf '{"transcript_path":"%s"}' "$T")"

req="$(playbook_original_request "$stdin_b")"
[ "$req" = "Build me a widget that does X. Original request text." ] \
  && echo "PASS: original request recovered, system record skipped" \
  || { echo "FAIL: original request was [$req]"; exit 1; }

M="$root/tests/hooks/fixtures/transcript-multiline.jsonl"
stdin_m="$(printf '{"transcript_path":"%s"}' "$M")"
mreq="$(playbook_original_request "$stdin_m")"
mexp="$(printf 'First paragraph of the ask.\nSecond paragraph with detail.\nThird line.')"
[ "$mreq" = "$mexp" ] \
  && echo "PASS: full multi-line original request recovered verbatim, later turn skipped" \
  || { echo "FAIL: multi-line request was [$mreq]"; exit 1; }

used="$(playbook_context_used "$stdin_b")"
[ "$used" = "10020" ] && echo "PASS: usage sum = last assistant input+cache" \
  || { echo "FAIL: used was [$used], expected 10020"; exit 1; }

win="$(playbook_declared_window "$stdin_b")"
[ "$win" = "1000000" ] && echo "PASS: declared window parsed" \
  || { echo "FAIL: window was [$win]"; exit 1; }

pct="$(playbook_context_percent "$stdin_t")"
[ "$pct" = "70" ] && echo "PASS: percent = round(100*used/window)" \
  || { echo "FAIL: percent was [$pct], expected 70"; exit 1; }

missing="$(playbook_context_percent '{"transcript_path":"/no/such/file"}')"
[ -z "$missing" ] && echo "PASS: silent empty on missing transcript" \
  || { echo "FAIL: expected empty, got [$missing]"; exit 1; }

removed=0
for fn in playbook_dir playbook_anchor playbook_ledger playbook_ensure_dir \
          playbook_anchor_init playbook_ledger_append playbook_anchor_read; do
  if declare -F "$fn" >/dev/null 2>&1; then echo "FAIL: $fn still defined"; removed=1; fi
done
[ "$removed" -eq 0 ] && echo "PASS: rejected file helpers removed" || exit 1
```

- [ ] **Step 3: Run it to verify it fails**

Run: `bash tests/hooks/test-helpers.sh`
Expected: FAIL on the first assertion (`playbook_original_request: command not found` or similar), because the helpers do not exist yet.

- [ ] **Step 4: Refactor `hooks/lib/playbook-common.sh`**

Keep `playbook_project_dir`, `playbook_json_escape`, `playbook_emit_context` and `playbook_emit_stop_nudge` exactly as they are. Delete `playbook_dir`, `playbook_anchor`, `playbook_ledger`, `playbook_ensure_dir`, `playbook_anchor_init`, `playbook_ledger_append`, `playbook_anchor_read`, and the GSD-bridge `playbook_context_percent`. Add the following (place after `playbook_project_dir`):

```bash
# Resolve the transcript path from hook stdin JSON. Empty if absent.
playbook_transcript_path() {
  jq -r '.transcript_path // empty' 2>/dev/null <<<"${1:-}" || printf ''
}

# The verbatim original request: the complete content of the first transcript
# record that is the human's own user message, with multi-line content
# preserved. Skips system/hook records (.type!="user"), records whose role is
# not "user", and tool-result turns (content is an array whose first element
# type is "tool_result"). Returns the full text, or empty on any failure.
# Silent degradation is mandatory: empty, never a wrong value.
playbook_original_request() {
  { local f; f="$(playbook_transcript_path "${1:-}")"
    [ -n "$f" ] && [ -f "$f" ] || { printf ''; return 0; }
    jq -rs 'map(select(.type=="user" and (.message.role=="user")
                       and ((.message.content|type)=="string"
                            or ((.message.content|type)=="array"
                                and (.message.content[0].type? != "tool_result")))))
            | (.[0] // empty)
            | .message.content
            | if type=="string" then .
              elif type=="array" then (map(select(.type=="text")|.text)|join("\n"))
              else empty end' "$f" 2>/dev/null
  } 2>/dev/null || printf ''
}

# Context tokens in use = the last assistant record's input-side usage, the
# exact formula Claude Code uses for used_percentage. Empty if unavailable.
playbook_context_used() {
  { local f; f="$(playbook_transcript_path "${1:-}")"
    [ -n "$f" ] && [ -f "$f" ] || { printf ''; return 0; }
    local v
    v="$(jq -r 'select(.message.usage)
                | .message.usage
                | ((.input_tokens // 0) + (.cache_creation_input_tokens // 0)
                   + (.cache_read_input_tokens // 0))' "$f" 2>/dev/null \
         | awk 'NF{last=$0} END{if(last!="")print last}')"
    case "$v" in ''|*[!0-9]*) printf '' ;; *) printf '%s' "$v" ;; esac
  } 2>/dev/null || printf ''
}

# The agent-declared nominal window: the most recent line matching the fixed
# prefix `playbook-window: <integer>` anywhere in the transcript. Empty if
# never declared.
playbook_declared_window() {
  { local f; f="$(playbook_transcript_path "${1:-}")"
    [ -n "$f" ] && [ -f "$f" ] || { printf ''; return 0; }
    local v
    v="$(grep -oE 'playbook-window:[[:space:]]*[0-9]+' "$f" 2>/dev/null \
         | tail -1 | grep -oE '[0-9]+' || true)"
    case "$v" in ''|*[!0-9]*) printf '' ;; *) printf '%s' "$v" ;; esac
  } 2>/dev/null || printf ''
}

# Integer percent of context used, or empty when either input is unavailable.
# Same return contract the take-a-beat caller already expects.
playbook_context_percent() {
  { local u w; u="$(playbook_context_used "${1:-}")"
    w="$(playbook_declared_window "${1:-}")"
    case "$u" in ''|*[!0-9]*) printf ''; return 0 ;; esac
    case "$w" in ''|*[!0-9]*) printf ''; return 0 ;; esac
    [ "$w" -gt 0 ] 2>/dev/null || { printf ''; return 0; }
    local p=$(( (u * 100 + w / 2) / w ))
    [ "$p" -lt 0 ] && p=0; [ "$p" -gt 100 ] && p=100
    printf '%s' "$p"
  } 2>/dev/null || printf ''
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/hooks/test-helpers.sh`
Expected: every line `PASS`. Then `bash -n hooks/lib/playbook-common.sh` exits 0.

- [ ] **Step 6: Commit**

```bash
git add hooks/lib/playbook-common.sh tests/hooks/test-helpers.sh tests/hooks/fixtures/transcript-basic.jsonl tests/hooks/fixtures/transcript-beat.jsonl tests/hooks/fixtures/transcript-multiline.jsonl
git commit -m "refactor: replace file/GSD helpers with transcript-derived helpers"
```

---

### Task 2: The `unease` hook (renamed from `uncertainty`)

**Files:**
- Rename: `hooks/uncertainty` to `hooks/unease` (via `git mv`)
- Modify: `hooks/unease`
- Rename: `tests/hooks/test-uncertainty.sh` to `tests/hooks/test-unease.sh` (via `git mv`)
- Modify: `tests/hooks/test-unease.sh`

- [ ] **Step 1: Rename both files**

```bash
git mv hooks/uncertainty hooks/unease
git mv tests/hooks/test-uncertainty.sh tests/hooks/test-unease.sh
```

- [ ] **Step 2: Write the failing test**

Replace the contents of `tests/hooks/test-unease.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/unease"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
out="$(echo '{"hook_event_name":"Stop"}' | bash "$H")"

jq -e '.hookSpecificOutput.additionalContext' <<<"$out" >/dev/null \
  && echo "PASS: model-visible additionalContext channel" || { echo FAIL channel; exit 1; }
jq -e '.hookSpecificOutput.hookEventName == "Stop"' <<<"$out" >/dev/null \
  && echo "PASS: hookEventName Stop" || { echo FAIL eventname; exit 1; }
jq -e '(.decision // "") != "block"' <<<"$out" >/dev/null \
  && echo "PASS: no forced block, turn can terminate" || { echo FAIL block; exit 1; }
jq -e '(.continue // true) == true' <<<"$out" >/dev/null \
  && echo "PASS: continue not disabled" || { echo FAIL continue; exit 1; }
ctx="$(jq -r '.hookSpecificOutput.additionalContext' <<<"$out")"
grep -q "near_breaking" <<<"$ctx" && grep -q "sharply_reduced" <<<"$ctx" \
  && echo "PASS: level and movement enums present in the constant prompt" \
  || { echo "FAIL: enums missing from prompt"; exit 1; }
grep -qi "only if it changed" <<<"$ctx" \
  && echo "PASS: silence-is-no-update instruction present" || { echo FAIL noupdate; exit 1; }
grep -q "regardless of the unease level or the mode" <<<"$ctx" \
  && echo "PASS: standing North-Star override verbatim, no ledger" || { echo FAIL override; exit 1; }
! grep -qi "ledger" <<<"$ctx" \
  && echo "PASS: no ledger vocabulary" || { echo "FAIL: ledger word present"; exit 1; }

for bad in '' 'not json at all' '{"hook_event_name":"Stop"' 'true'; do
  if bo="$(printf '%s' "$bad" | bash "$H" 2>/dev/null)"; then :; else
    echo "FAIL: stdin [$bad] aborted the hook (exit non-zero)"; exit 1; fi
  jq -e '.hookSpecificOutput.additionalContext' <<<"$bo" >/dev/null \
    && jq -e '.hookSpecificOutput.hookEventName == "Stop"' <<<"$bo" >/dev/null \
    || { echo "FAIL: stdin [$bad] did not yield a valid Stop envelope"; exit 1; }
done
echo "PASS: empty and non-JSON stdin still yield a valid Stop envelope"

d_tmp="$(mktemp -d)"
printf '{"hook_event_name":"Stop","cwd":"%s"}' "$d_tmp" | bash "$H" >/dev/null 2>&1 || true
[ ! -e "$d_tmp/.playbook" ] && echo "PASS: writes no file into the project" \
  || { rm -rf "$d_tmp"; echo "FAIL: hook created .playbook"; exit 1; }
rm -rf "$d_tmp"
```

- [ ] **Step 3: Run it to verify it fails**

Run: `bash tests/hooks/test-unease.sh`
Expected: FAIL (old hook still emits the confidant-gate ledger prompt; `near_breaking` and the no-ledger assertions fail).

- [ ] **Step 4: Rewrite `hooks/unease`**

Replace the contents of `hooks/unease` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/playbook-common.sh"
stdin="$(cat 2>/dev/null || true)"   # computes nothing; only reads the event name to label the output
event="$(jq -r '.hook_event_name // "Stop"' 2>/dev/null <<<"$stdin" || true)"
[ -n "$event" ] || event="Stop"

prompt="Unease pulse. After this action, restate your unease only if it changed: a level (one of clear, settled, attentive, watchful, faintly_uneasy, uneasy, concerned, strained, troubled, alarmed, near_breaking) and a last movement (one of maintained, slightly_increased, increased, sharply_increased, barely_reduced, slightly_reduced, reduced, sharply_reduced) then a colon and a reason of at most 50 characters. If nothing changed, say nothing: silence means maintained with no movement. Unease is measured against the North Star and is the whole project's, not just this task; it can be high and you still choose not to escalate. If your restatement is an increase, the escalation ladder is available as a second-order option you will usually decline: self and re-read the North Star, take a beat, research, a fresh subagent for a second pair of eyes, notify the user via ntfy and wait, then an external manager. Standing override, above all of this: if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode."

playbook_emit_context "$event" "$prompt"
exit 0
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/hooks/test-unease.sh`
Expected: every line `PASS`. Then `bash -n hooks/unease` exits 0.

- [ ] **Step 6: Commit**

```bash
git add hooks/unease tests/hooks/test-unease.sh
git commit -m "refactor: rename uncertainty hook to unease, constant in-session pulse"
```

---

### Task 3: The `take-a-beat` hook (seam plus transcript context signal)

**Files:**
- Modify: `hooks/take-a-beat`
- Modify: `tests/hooks/test-take-a-beat.sh`
- Delete: `tests/hooks/fixtures/ctx-used-40.json`, `tests/hooks/fixtures/ctx-used-70.json`, `tests/hooks/fixtures/ctx-remaining-35.json`

- [ ] **Step 1: Write the failing test**

Replace the contents of `tests/hooks/test-take-a-beat.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/take-a-beat"
export CLAUDE_PLUGIN_ROOT="$root"
unset CURSOR_PLUGIN_ROOT COPILOT_CLI 2>/dev/null || true
B="$root/tests/hooks/fixtures/transcript-basic.jsonl"
T="$root/tests/hooks/fixtures/transcript-beat.jsonl"

# PreCompact: steer that names the carried items, no file read.
out="$(printf '{"hook_event_name":"PreCompact","transcript_path":"%s"}' "$B" | bash "$H")"
jq -e '.hookSpecificOutput.additionalContext | test("Compact Instructions")' <<<"$out" >/dev/null \
  && echo "PASS: precompact steers" || { echo FAIL precompact; exit 1; }
grep -q "Lessons and wrong turns" <<<"$out" && echo "PASS: lessons named" || { echo FAIL lessons; exit 1; }
grep -q "playbook-window" <<<"$out" && echo "PASS: declared window carried" || { echo FAIL window; exit 1; }

# Post-compaction: original request recovered from the transcript with primacy.
out="$(printf '{"hook_event_name":"PostCompact","transcript_path":"%s"}' "$B" | bash "$H")"
grep -q "Build me a widget that does X. Original request text." <<<"$out" \
  && echo "PASS: original request re-injected from transcript" || { echo FAIL reanchor; exit 1; }
out="$(printf '{"hook_event_name":"SessionStart","source":"compact","transcript_path":"%s"}' "$B" | bash "$H")"
grep -q "Build me a widget that does X. Original request text." <<<"$out" \
  && echo "PASS: SessionStart/compact also recovers" || { echo FAIL reanchor2; exit 1; }

# Below threshold: silent (basic fixture is ~1 percent of 1,000,000).
out="$(printf '{"hook_event_name":"PostToolUse","transcript_path":"%s"}' "$B" | bash "$H")"
[ -z "$out" ] && echo "PASS: no beat under 65 percent" || { echo FAIL spurious; exit 1; }

# At/over threshold: announces the beat (beat fixture is 70 percent).
out="$(printf '{"hook_event_name":"PostToolUse","transcript_path":"%s"}' "$T" | bash "$H")"
grep -qi "taking a beat" <<<"$out" && echo "PASS: beat at 70 percent" || { echo FAIL nobeat; exit 1; }

# Unrelated event: silent.
out="$(printf '{"hook_event_name":"Stop","transcript_path":"%s"}' "$B" | bash "$H")"
[ -z "$out" ] && echo "PASS: silent on non-handled events" || { echo FAIL stop; exit 1; }

# Malformed or empty stdin: silent, no abort, exit 0.
for bad in '' 'not json' '{"hook_event_name":"PostToolUse"'; do
  if mo="$(printf '%s' "$bad" | bash "$H" 2>/dev/null)"; then :; else
    echo "FAIL: stdin [$bad] aborted take-a-beat"; exit 1; fi
  [ -z "$mo" ] || { echo "FAIL: stdin [$bad] was not silent: [$mo]"; exit 1; }
done
echo "PASS: malformed or empty stdin is silent, no abort"

# Never creates a file in the project.
d="$(mktemp -d)"
printf '{"hook_event_name":"PostToolUse","cwd":"%s","transcript_path":"%s"}' "$d" "$T" | bash "$H" >/dev/null 2>&1 || true
[ ! -e "$d/.playbook" ] && echo "PASS: no file written" || { rm -rf "$d"; echo FAIL wrotefile; exit 1; }
rm -rf "$d"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/hooks/test-take-a-beat.sh`
Expected: FAIL (current hook reads `playbook_anchor_read` and the GSD bridge; recovery and threshold assertions fail).

- [ ] **Step 3: Delete the GSD fixtures**

```bash
git rm tests/hooks/fixtures/ctx-used-40.json tests/hooks/fixtures/ctx-used-70.json tests/hooks/fixtures/ctx-remaining-35.json
```

- [ ] **Step 4: Rewrite `hooks/take-a-beat`**

Replace the contents of `hooks/take-a-beat` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/playbook-common.sh"

stdin="$(cat 2>/dev/null || true)"
event="$(jq -r '.hook_event_name // empty' 2>/dev/null <<<"$stdin" || true)"
orig="$(playbook_original_request "$stdin")"

reanchor() {
  [ -n "$orig" ] || return 0
  playbook_emit_context "$1" "Playbook anchor, restored first, before any orchestration scaffolding.

Original request, verbatim:
${orig}

Re-establish the one-line North Star and your current unease from this original request and the live work. Re-state your context window as a single line of the form playbook-window: <integer> if it is not already visible."
}

case "$event" in
  PreCompact)
    playbook_emit_context "PreCompact" "## Compact Instructions
When summarising, preserve verbatim and ahead of orchestration scaffolding: the original request, the current one-line North Star, the Lessons and wrong turns (including silent wrong turns, not only errors with a stack trace), the current unease level and last movement, and the most recent playbook-window line. Re-anchor the summary on the original request and the next work.

Original request, verbatim:
${orig}"
    ;;
  PostCompact)            reanchor "PostCompact" ;;
  SessionStart)
    src="$(jq -r '.source // empty' 2>/dev/null <<<"$stdin" || true)"
    [ "$src" = "compact" ] && reanchor "SessionStart"
    ;;
  PostToolUse)
    pct="$(playbook_context_percent "$stdin" || true)"
    if [ -n "$pct" ] && [ "$pct" -ge 65 ] 2>/dev/null; then
      playbook_emit_context "PostToolUse" "Taking a beat: context is at ${pct} percent used. Pause, re-read the original request and the North Star, carry the lessons and wrong turns forward rather than discarding them as historical, then continue with a fresh head.

Original request, verbatim:
${orig}"
    fi
    ;;
  *) : ;;
esac
exit 0
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `bash tests/hooks/test-take-a-beat.sh`
Expected: every line `PASS`. Then `bash -n hooks/take-a-beat` exits 0.

- [ ] **Step 6: Commit**

```bash
git add hooks/take-a-beat tests/hooks/test-take-a-beat.sh
git rm -q --cached tests/hooks/fixtures/ctx-used-40.json tests/hooks/fixtures/ctx-used-70.json tests/hooks/fixtures/ctx-remaining-35.json 2>/dev/null || true
git commit -m "refactor: take-a-beat recovers anchor from transcript, no file or GSD"
```

---

### Task 4: The `session-start` overlay

**Files:**
- Modify: `hooks/session-start`
- Modify: `tests/hooks/test-session-start.sh`

- [ ] **Step 1: Write the failing test**

Replace the contents of `tests/hooks/test-session-start.sh` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
H="$root/hooks/session-start"
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
out="$(printf '{"cwd":"%s","hook_event_name":"SessionStart","source":"startup"}' "$tmp" | bash "$H")"
ctx="$(jq -r '.hookSpecificOutput.additionalContext // .additional_context // .additionalContext' <<<"$out")"
[ -n "$ctx" ] && echo "PASS: overlay injected" || { echo FAIL; exit 1; }
grep -q "PLAYBOOK_OVERLAY" <<<"$ctx" && echo "PASS: sentinel tag" || { echo FAIL tag; exit 1; }
n=$(grep -cE '^[1-9]\. ' <<<"$ctx"); [ "$n" -eq 9 ] && echo "PASS: nine tenets" || { echo "FAIL: $n tenets"; exit 1; }
grep -q "regardless of the unease level or the mode" <<<"$ctx" \
  && echo "PASS: standing override verbatim, no ledger" || { echo FAIL override; exit 1; }
! grep -q '\.playbook/' <<<"$ctx" && ! grep -qi 'anchor file is the persistence' <<<"$ctx" \
  && echo "PASS: no file-persistence claim" || { echo "FAIL: still claims a file persists"; exit 1; }
! grep -qi 'uncertainty' <<<"$ctx" && echo "PASS: unease naming" || { echo "FAIL: uncertainty word present"; exit 1; }
jq -e . <<<"$out" >/dev/null && echo "PASS: valid JSON" || { echo FAIL json; exit 1; }
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/hooks/test-session-start.sh`
Expected: FAIL (current overlay says the `.playbook/anchor.md` file is the persistence mechanism and uses "uncertainty").

- [ ] **Step 3: Rewrite `hooks/session-start`**

Replace the contents of `hooks/session-start` with:

```bash
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/playbook-common.sh"
stdin="$(cat 2>/dev/null || true)"
orig="$(playbook_original_request "$stdin")"

overlay="<PLAYBOOK_OVERLAY>
Playbook is active. This overlay and the hooks are the persistence mechanism, not skill text and not any file: nothing is written into your working tree. State is carried in this conversation, steered across compaction by the hooks, and re-derived if a compaction loses it. The overlay stays in force across subagents and compaction and takes precedence over default behaviour where they conflict, though explicit user instructions still win. For any non-trivial work the playbook:playbook engine makes one visible, vetoable staffing call before planning or coding.

State the original request's one-line North Star and keep it load-bearing at every decision. State your context window once as a single line of the form playbook-window: <integer> so the take-a-beat hook can read it.

The nine tenets, always live:
1. Remember what matters: the original request is recovered from the transcript with primacy after compaction; keep the one-line North Star load-bearing and restate it at checkpoints.
2. Ask questions once, upfront and batched; there are no stupid questions; do not drip-feed, though stopping to ask later is allowed.
3. Treat the team as equals: a lead or conductor holds coordination authority only, not intellectual authority; subagents push back with technical reasoning; peer sanity-check is the routine cheap path before escalating.
4. Unease: after every agent action restate your unease level and last movement only if they changed; silence means maintained with no movement; the escalation ladder is offered only on an increase and usually declined.
5. Offline behaviour is enabled only by playbook:offline-mode, explicitly and per run.
6. Production-ready: no scaffolding vocabulary (plan, wave, mission) or comment sludge in shipped code; sweep before handing work back.
7. Take a beat at about 65 percent context used: pause, re-read the original request and the North Star, carry lessons forward; compaction is a steered breath, not a wipe.
8. Less is more: pick the cheapest sufficient mode; short questions, plans and comments; longer thinking and shorter output; give subagents freedom.
9. Speed via more hands, not rushing: fan separable work across agents at the same completeness bar; partial work to save time is forbidden; never rush unless the user says to rush.

Standing override, above everything: if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode.
</PLAYBOOK_OVERLAY>"

if [ -n "$orig" ]; then
  body="${overlay}

Playbook anchor, restored first, before any orchestration scaffolding.

Original request, verbatim:
${orig}"
else
  body="$overlay"
fi

playbook_emit_context "SessionStart" "$body"
exit 0
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/hooks/test-session-start.sh`
Expected: every line `PASS`. Then `bash -n hooks/session-start` exits 0.

- [ ] **Step 5: Commit**

```bash
git add hooks/session-start tests/hooks/test-session-start.sh
git commit -m "refactor: session-start overlay states the in-session no-file model"
```

---

### Task 5: Hook wiring in `hooks/hooks.json`

**Files:**
- Modify: `hooks/hooks.json`
- Modify: `tests/manifests.sh`

- [ ] **Step 1: Write the failing manifest assertions**

Insert into `tests/manifests.sh` immediately before its final `exit $fail` line:

```bash
assert "jq -e '.hooks.Stop[0].hooks[] | select(.command|test(\"unease\"))' '$root/hooks/hooks.json'" "Stop wired to unease"
assert "jq -e '.hooks.PostToolUse[0].hooks | map(.command) | any(test(\"unease\")) and any(test(\"take-a-beat\"))' '$root/hooks/hooks.json'" "PostToolUse wired to unease and take-a-beat"
assert "jq -e '.hooks.PreCompact and .hooks.PostCompact' '$root/hooks/hooks.json'" "PreCompact and PostCompact wired"
assert "! grep -q 'uncertainty' '$root/hooks/hooks.json'" "no uncertainty reference in hooks.json"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/manifests.sh`
Expected: FAIL on "Stop wired to unease" and "no uncertainty reference" (hooks.json still wires `uncertainty`).

- [ ] **Step 3: Replace `hooks/hooks.json`**

```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup|clear|compact", "hooks": [
        { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" session-start", "async": false },
        { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" take-a-beat", "async": false }
      ] }
    ],
    "PreCompact": [
      { "matcher": "manual|auto", "hooks": [
        { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" take-a-beat", "async": false }
      ] }
    ],
    "PostCompact": [
      { "matcher": "manual|auto", "hooks": [
        { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" take-a-beat", "async": false }
      ] }
    ],
    "PostToolUse": [
      { "matcher": "*", "hooks": [
        { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" unease", "async": false },
        { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" take-a-beat", "async": false }
      ] }
    ],
    "Stop": [
      { "matcher": "*", "hooks": [
        { "type": "command", "command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" unease", "async": false }
      ] }
    ]
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/manifests.sh`
Expected: every line `PASS`. Then `jq -e . hooks/hooks.json` exits 0.

- [ ] **Step 5: Commit**

```bash
git add hooks/hooks.json tests/manifests.sh
git commit -m "refactor: rewire hooks.json for unease and the seam events"
```

---

### Task 6: Engine doctrine in `skills/playbook/SKILL.md`

**Files:**
- Modify: `skills/playbook/SKILL.md`
- Create: `tests/hooks/test-doctrine.sh`

- [ ] **Step 1: Write the failing doctrine assertions**

Create `tests/hooks/test-doctrine.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
S="$root/skills/playbook/SKILL.md"
fail=0
chk() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }
chk "! grep -q '\.playbook/' '$S'" "no .playbook/ paths"
chk "! grep -q 'playbook_anchor_init\\|playbook_ledger_append\\|playbook_anchor_read' '$S'" "no removed helpers"
chk "! grep -q 'anchor-format' '$S'" "no anchor-format.md cross-references"
chk "! grep -qi 'uncertaint' '$S'" "no uncertainty word anywhere (concept, hook name, ledger)"
chk "! grep -qiE 'append-only( unease)? ledger|unease ledger|the ledger|band-slug|callout shape' '$S'" "ledger mechanism gone"
chk "! grep -qiE 'the anchor file|pinned anchor file|re-?reads? the anchor|into the anchor' '$S'" "no anchor-file references"
chk "! grep -qE '(^|[^-])design\\.md' '$S'" "no bare design.md, plan-a-design.md allowed"
chk "grep -q 'plan-a-design\\.md' '$S'" "canonical doc named plan-a-design.md"
chk "grep -q 'regardless of the unease level or the mode' '$S'" "standing override no-ledger phrasing"
chk "grep -q 'playbook-window' '$S'" "agent-declared window instruction present"
chk "grep -qiE 'recovered from the transcript|recovers it verbatim from .transcript_path.' '$S'" "transcript-recovery doctrine present"
exit $fail
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/hooks/test-doctrine.sh`
Expected: FAIL on `.playbook/`, helpers, anchor-format, ledger, design.md.

- [ ] **Step 3: Apply the mechanical sweeps to `skills/playbook/SKILL.md`**

- Apply this step before Steps 4 to 9. Replace every bare token `design.md` with `plan-a-design.md`. Do not count occurrences; one of them sits inside the tenet-4 band table that Step 6 deletes wholesale, so the surviving count after Step 6 is lower. Match only the bare token and never re-replace an existing `plan-a-design.md`: the regex `(^|[^-])design\.md` distinguishes the bare token from the already-correct compound.
- Remove every `docs/playbook/anchor-format.md` cross-reference (three occurrences, all in tenet 1 and tenet 4 prose) along with the clause that introduces it.

- [ ] **Step 4: Replace the engine-flow step 1 (line 22)**

Old: `1. **Restate the North Star.** One line of what matters, written verbatim from the user's request into the anchor file (`.playbook/anchor.md`). For trivial work this is one line and there are zero questions.`

New:

```markdown
1. **Restate the North Star.** One line of what matters, derived verbatim from the user's request and kept load-bearing in the conversation. It is never written to a file. For trivial work this is one line and there are zero questions.
```

- [ ] **Step 5: Replace tenet 1 (line 148)**

```markdown
1. **Remember what's important.** Native compaction reconstructs intent from a flat, unweighted message list, so orchestration scaffolding can outrank the original request. The original request is the first human message in the transcript; the `take-a-beat` hook recovers it verbatim from `transcript_path` and re-injects it with primacy after every compaction. Keep the one-line North Star load-bearing at every decision and restate it at checkpoints. State your context window once as a single line of the form `playbook-window: <integer>` so `take-a-beat` can compute the context percent. Nothing is written into the user's working tree: the conversation is the store and the hooks steer it.
```

- [ ] **Step 6: Replace tenet 4 (line 151 through the band table to the end of line 161)**

Replace the whole of tenet 4, including the band-slug table and the callout-shape paragraph, with:

```markdown
4. **Unease.** The model asks only when it feels blocked; there is no calibrated confidence signal and no rule tying a mandatory stop to the goal. Unease is an in-session sense, not a file and not a score. After every agent action, restate your unease only if it changed: a level (one of `clear`, `settled`, `attentive`, `watchful`, `faintly_uneasy`, `uneasy`, `concerned`, `strained`, `troubled`, `alarmed`, `near_breaking`) and a last movement (one of `maintained`, `slightly_increased`, `increased`, `sharply_increased`, `barely_reduced`, `slightly_reduced`, `reduced`, `sharply_reduced`) then a colon and a reason of at most 50 characters. Silence means maintained with no movement. Unease is the whole project's, measured against the North Star, not just the current task; it can be high while you still choose not to escalate. Only when a restatement is an increase is the escalation ladder offered, as a second-order option you will usually decline. The `unease` hook is a stateless constant prompt that fires every action and computes nothing. Standing override, above all of this: if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode.
```

- [ ] **Step 7: Replace the standing-override block at lines 32, 161 (inside the new tenet 4) and 172**

Every verbatim standing-override quotation currently reading `... regardless of the uncertainty ledger or the mode.` becomes:

```
if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode.
```

Apply at line 32 (engine-flow standing rule), inside the rewritten tenet 4 (already carried in Step 6), line 172 (escalation-ladder standing override), and line 170 (`independent of the uncertainty ledger and above the ladder` becomes `independent of the unease sense and above the ladder`).

- [ ] **Step 8: Replace escalation-ladder step 6 (line 181) and the tenet 3 clause (line 150)**

Line 181 old fragment `... and gated by the uncertainty ledger so it is never routine.` becomes `... and gated by your in-session unease so it is never routine.` Line 182 `... where the ledger warrants.` becomes `... where your unease warrants.` Line 150 `external-manager escalation is gated by the uncertainty ledger so it never becomes ceremony` becomes `external-manager escalation is gated by your in-session unease so it never becomes ceremony`.

- [ ] **Step 9: Replace the Red Flags and Integration references (lines 203, 208, 232 to 234)**

- Line 203: `Persistence comes from the `take-a-beat` and `uncertainty` hooks plus the anchor file, not from skill text being re-read` becomes `Persistence comes from the `take-a-beat` and `unease` hooks carrying state in-session, not from a file and not from skill text being re-read`.
- Line 208: delete the bullet `Expect a `decision:block` from the `uncertainty` hook; it is fire-and-forget and only nudges.` and replace with `Expect a `decision:block` from the `unease` hook; it is a stateless constant prompt and only nudges.`
- Line 207: delete the bullet about inlining `$(...)` at the `playbook_anchor_init` call site (the helper no longer exists).
- Lines 233 to 234: `take-a-beat (tenet 7) fires at ~65% context used.` keep; `uncertainty (tenet 4) fires at the end of every turn and nudges the confidant test; it never logs anything itself.` becomes `unease (tenet 4) fires after every agent action and prompts the unease restatement; it is stateless and writes nothing.`
- Line 211 (Always): `Restate the North Star into the anchor before anything else` becomes `Restate the North Star and keep it load-bearing before anything else`.
- Engine-flow step 5: `Keep the tenets doctrine and the anchor file live throughout` becomes `Keep the North Star, the unease sense and the tenets doctrine live in the conversation throughout`.
- The overlay-intro sentence: `comes from the two hooks plus the pinned anchor file, not from this skill text being re-read` becomes `comes from the two hooks carrying state in-session, not from this skill text being re-read`.
- Escalation-ladder step 1: `Take a breath, re-read the anchor.` becomes `Take a breath, re-read the original request and the North Star.`
- Replace tenet 7 entirely with: `7. **Take a beat.** Native compaction is fixed-schema, fires only at the hard limit, has no lessons-learned slot and re-anchors weakly. The `take-a-beat` hook fires at about 65 percent context used, computed from the transcript usage sum over your declared window. It announces the beat, recovers the original request from the transcript, carries the lessons and wrong turns forward rather than discarding them as historical, and re-anchors on the original request and upcoming work with primacy over orchestration scaffolding. Nothing is read from or written to a file.`
- The Step 1 assertions are the gate: after this step grep the whole `skills/playbook/SKILL.md` and confirm no `.playbook/`, removed helper, `anchor-format`, `uncertaint`, ledger or anchor-file vocabulary, or bare `design.md` survives anywhere. The line lists in Steps 3 to 9 are guidance, not exhaustive; fix any survivor the grep finds.

- [ ] **Step 10: Run the doctrine test and the long-dash sweep**

Run: `bash tests/hooks/test-doctrine.sh`
Expected: every line `PASS`.
Run: `perl -CSD -ne 'print "L$.: $_" if /\x{2014}|\x{2013}/' skills/playbook/SKILL.md`
Expected: no output. perl -CSD decodes UTF-8 so the codepoint match is sound and host-portable; plain perl without -CSD, and grep -P on BSD grep, are both silent no-ops.

- [ ] **Step 11: Commit**

```bash
git add skills/playbook/SKILL.md tests/hooks/test-doctrine.sh
git commit -m "refactor: engine doctrine to the in-session no-file unease model"
```

---

### Task 7: `skills/offline-mode/SKILL.md` ledger conversion

**Files:**
- Modify: `skills/offline-mode/SKILL.md`

- [ ] **Step 1: Write the failing assertion**

Insert into `tests/hooks/test-doctrine.sh` immediately before its final `exit $fail` line:

```bash
O="$root/skills/offline-mode/SKILL.md"
chk "! grep -qi 'uncertaint' '$O'" "offline-mode has no uncertainty word anywhere"
chk "! grep -qiE 'uncertainty ledger|the ledger' '$O'" "offline-mode has no ledger reference"
chk "! grep -qE '(^|[^-])design\\.md' '$O'" "offline-mode no bare design.md, plan-a-design.md allowed"
chk "grep -q 'regardless of the unease level or the mode' '$O'" "offline-mode standing override no-ledger phrasing"
chk "grep -qi 'gated by your in-session unease\\|gated by the in-session unease' '$O'" "external manager gated by in-session unease"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/hooks/test-doctrine.sh`
Expected: FAIL on the three new offline-mode assertions.

- [ ] **Step 3: Convert every rejected-model reference**

Step 1's assertions are the gate: no `uncertaint` word, no `uncertainty ledger` or bare `the ledger`, and no bare `design.md` may remain anywhere in `skills/offline-mode/SKILL.md`. The known sites follow; grep the whole file afterwards and fix any survivor. Apply these transformations:

- Line 44: `independent of the uncertainty ledger and the mode:` becomes `independent of the unease sense and the mode:`
- Line 46 and line 152 standing-override quotation: `regardless of the uncertainty ledger or the mode.` becomes `regardless of the unease level or the mode.`
- Lines 50 and 51: `having consulted the external manager first where the uncertainty ledger warrants` becomes `having consulted the external manager first where your in-session unease warrants`.
- Line 57: the sentence `The external manager is consulted first where the ledger warrants.` becomes `The external manager is consulted first where your in-session unease warrants.` Note the different sentence stem and that line 57 reads `where the ledger warrants`, not `where the uncertainty ledger warrants`; a literal search for the line 50/51 string will not match it.
- Line 56 and line 152: `Gated by the uncertainty ledger so it is never routine.` and `the external manager gated by the uncertainty ledger` become `Gated by your in-session unease so it is never routine.` and `the external manager gated by your in-session unease`.
- Diagram nodes lines 94, 111, 114, 115: the node label `"External manager, gated by the uncertainty ledger"` becomes `"External manager, gated by in-session unease"` (rename consistently so every edge still resolves).
- Line 134 (Red Flags): `It is gated by the uncertainty ledger.` becomes `It is gated by your in-session unease.`
- Line 142 (Always): `where the uncertainty ledger warrants` becomes `where your in-session unease warrants`.
- Line 46 standing-override quotation: the leading clause `if an uncertainty or decision could degrade` becomes `if a decision could degrade`, so the whole quotation reads `if a decision could degrade the North Star such that the work would no longer meet it, stop and ask the user before proceeding, regardless of the unease level or the mode.` Apply this to every standing-override quotation in the file.
- Any other bare `uncertainty` or `uncertaint` word anywhere in the file becomes `unease`, so the Step 1 `! grep -qi 'uncertaint'` assertion passes.
- Every bare `design.md` becomes `plan-a-design.md` (match only the bare token with `(^|[^-])design\.md`; never re-replace an existing `plan-a-design.md`). There are several across the prose and the Integration list.

The offline behaviour itself (the ntfy notify-and-wait, the per-run wait window, the external manager, the HTML log) is unchanged.

- [ ] **Step 4: Run the test and sweep**

Run: `bash tests/hooks/test-doctrine.sh`
Expected: every line `PASS`.
Run: `perl -CSD -ne 'print "L$.: $_" if /\x{2014}|\x{2013}/' skills/offline-mode/SKILL.md`
Expected: no output. perl -CSD is the sound, host-portable check.

- [ ] **Step 5: Commit**

```bash
git add skills/offline-mode/SKILL.md tests/hooks/test-doctrine.sh
git commit -m "refactor: offline-mode gated by in-session unease, no ledger"
```

---

### Task 8: `README.md` and `.gitignore`

**Files:**
- Modify: `README.md`
- Modify: `.gitignore`

- [ ] **Step 1: Write the failing assertion**

Insert into `tests/hooks/test-doctrine.sh` immediately before its final `exit $fail` line:

```bash
R="$root/README.md"
chk "! grep -qE '\.playbook/[A-Za-z._-]' '$R'" "README has no .playbook/ path references"
chk "! grep -qi 'uncertaint' '$R'" "README uses unease naming, no uncertainty word"
chk "grep -qi 'writes no file into' '$R'" "README states no file is written into the tree"
chk "! grep -q '\.playbook/' '$root/.gitignore'" ".gitignore has no .playbook vestige"
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/hooks/test-doctrine.sh`
Expected: FAIL on the README and .gitignore assertions.

- [ ] **Step 3: Rewrite README.md**

- Line 30: `enforced by the engine doctrine plus the two hooks and the pinned anchor file rather than by skill text being re-read.` becomes `enforced by the engine doctrine plus the two hooks carrying state in-session rather than by skill text being re-read.`
- Line 35 (tenet 4 bullet): replace with `4. **Unease.** An in-session unease pulse restated after every agent action, never a file or a score; the escalation ladder is offered only on an increase; a standing override stops and asks the user whenever the North Star would no longer be met.`
- Lines 44 to 45 (the two hooks): `take-a-beat` bullet `re-reads the anchor and lessons ledger` becomes `recovers the original request from the transcript and re-anchors with primacy`; replace the `uncertainty` bullet with `**`unease`** (tenet 4): fires after every agent action and prompts the unease restatement. It is stateless, computes nothing, and writes nothing.`
- Replace the whole `## Runtime state` section (lines 56 to 63) with:

```markdown
## Runtime state

Playbook writes no file into your working tree. There is no `.playbook/` directory, no anchor file and no ledger. The original request, the North Star and the unease sense are held in the conversation, steered across compaction by the hooks, and re-derived if a compaction loses them. A fresh session starts clean.
```

- [ ] **Step 4: Edit `.gitignore`**

Remove the line `.playbook/`. Leave `.DS_Store` and `.worktrees/`.

- [ ] **Step 5: Run the test and sweep**

Run: `bash tests/hooks/test-doctrine.sh`
Expected: every line `PASS`.
Run: `perl -CSD -ne 'print "L$.: $_" if /\x{2014}|\x{2013}/' README.md`
Expected: no output. perl -CSD is the sound, host-portable check.

- [ ] **Step 6: Commit**

```bash
git add README.md .gitignore tests/hooks/test-doctrine.sh
git commit -m "refactor: README and .gitignore to the no-file model"
```

---

### Task 9: Sanctioned edits to `plan-a-design.md`

**Files:**
- Modify: `plan-a-design.md`
- Create: `tests/hooks/test-plan-a-sanctioned.sh`

These are the only edits `plan-a-design.md` receives (plan-c §11). Apply them seamlessly so the document reads as though always written that way, never as a changelog.

- [ ] **Step 1: Write the failing assertion**

Create `tests/hooks/test-plan-a-sanctioned.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
P="$root/plan-a-design.md"
fail=0
chk() { if eval "$1" >/dev/null 2>&1; then echo "PASS: $2"; else echo "FAIL: $2"; fail=1; fi; }
chk "! grep -qi 'uncertainty' '$P'" "concept renamed to unease everywhere including Appendix A"
chk "! grep -qE '\.playbook/[A-Za-z._-]' '$P'" "no .playbook/ path references"
chk "! grep -qi 'uncertainty-ledger\\|pinned anchor file' '$P'" "section 6 no longer file-based"
chk "! grep -qiE 'unease ledger|the unease ledger' '$P'" "plan-a no surviving ledger-mechanism phrasing"
chk "! grep -qiE 'the ledger warrants|gated by the [a-z ]*ledger' '$P'" "plan-a no surviving positive ledger-gate phrasing (D3)"
chk "grep -q 'ntfy' '$P'" "tenet 5 ntfy adaptation preserved"
chk "grep -qi '65% context\\|65 percent context\\|sixty-five percent' '$P'" "tenet 7 context adaptation preserved"
chk "grep -qi 'external manager' '$P'" "tenet 3 external-manager adaptation preserved"
chk "perl -CSD -ne 'exit 1 if /\\x{2014}|\\x{2013}/' '$P'" "no long dashes (perl -CSD is sound and host-portable; grep -P is absent on BSD grep)"
exit $fail
```

- [ ] **Step 2: Run it to verify it fails**

Run: `bash tests/hooks/test-plan-a-sanctioned.sh`
Expected: FAIL on the uncertainty, section-6 and ledger-phrasing assertions. The `.playbook/` path assertion already passes pre-edit because the source uses only the prose token `` `.playbook/` ``, never a real path; that is expected, not a problem.

- [ ] **Step 3: Apply the rename**

Replace the concept word `uncertainty` with `unease` at every occurrence in `plan-a-design.md`, including Appendix A. Do not count occurrences; rely on the Step 1 assertion `! grep -qi 'uncertainty'` to confirm none remain anywhere in the file, including the Appendix A verbatim block. Do not hardcode a count. Renaming inside the Appendix A verbatim block is the one sanctioned modification to it, per plan-c section 11 and Annex 2 section 1. `anxiety` is confirmed absent (`grep -i anxiety plan-a-design.md` returns nothing), so no `anxiety` rename is needed. Do not introduce long dashes. The tenet remains conceptually tenet 4; only the concept word changes.

- [ ] **Step 4: Rewrite section 6 and its dependents**

Replace section 6 (`## 6. The pinned anchor file and the unease ledger`, lines 153 to 180 inclusive) with a section that states the in-session no-file mechanism, drawing its content from `plan-c-refactor.md` sections 2, 3, 4, 5, 6 and 10. The replacement section, titled `## 6. The in-session anchor and the unease sense`, states: the original request is recovered from the transcript by the hooks and re-injected with primacy after compaction; the North Star and the unease level and movement are restated working state carried in the conversation; the context signal is the transcript usage sum over the agent-declared window; nothing is written into the user's working tree. Step 3 has already renamed the concept, so this heading now reads `## 6. The pinned anchor file and the unease ledger`; quote whichever form is present when you run this step. Also rewrite every other reference to the pinned anchor file and the ledger to the in-session mechanism, not only section 6: the section 3 introduction and its tenet-1 table cell, the component-inventory line naming "the pinned anchor file protocol", and the section 8, 11 and 12 references; the section 8 set explicitly includes the escalation-ladder step 7 clause, where `having consulted the external manager first where the ledger warrants` becomes `having consulted the external manager first where your in-session unease warrants` (matching the already-shipped offline-mode sibling and plan-c section 7, so section 8 reads "unease" in both step 6 and step 7 and never "ledger"). After this step `grep -i 'pinned anchor file' plan-a-design.md` must return nothing, so the Step 1 assertion passes. In section 12 remove the open item "Exact on-disk paths for the anchor file and the unease ledger" (it no longer applies). Also delete the now-false long-dash-exemption clause in the Appendix A preamble (the sentence stating the punctuation "is not subject to the British-English and no-long-dash build constraint", and any parallel clause elsewhere), because plan-c section 13 abolishes that inherited exemption and the file already contains zero long dashes; removing it keeps the document reading as though always written that way.

- [ ] **Step 5: Add the for-the-avoidance-of-doubt note**

`plan-a-design.md` already carries no section 13. Append, after section 12 and before Appendix A, a `## 13. For the avoidance of doubt` section stating verbatim that Playbook writes no file into the user's working tree, there is no `.playbook/` directory, no anchor file and no ledger, and the state is held in-session and re-derived after compaction. This matches plan-c §10 and is a permitted FAQ-style clarification, not a changelog.

- [ ] **Step 6: Run the test and the full sweep**

Run: `bash tests/hooks/test-plan-a-sanctioned.sh`
Expected: every line `PASS`.

- [ ] **Step 7: Commit**

```bash
git add plan-a-design.md tests/hooks/test-plan-a-sanctioned.sh
git commit -m "refactor: apply sanctioned section 11 edits to plan-a-design.md"
```

---

### Task 10: Test-suite cleanup and full green

**Files:**
- Delete: `tests/hooks/test-anchor.sh`, `tests/hooks/test-coverage-supplement.sh`, `tests/hooks/test-context-percent.sh`
- Modify: `tests/run-all.sh`

- [ ] **Step 1: Remove the rejected-model tests**

```bash
git rm tests/hooks/test-anchor.sh tests/hooks/test-coverage-supplement.sh tests/hooks/test-context-percent.sh
```

- [ ] **Step 2: Fix `tests/run-all.sh`**

- Line 5: change the lint loop target `"$root"/../hooks/uncertainty` to `"$root"/../hooks/unease`.
- Line 8: replace the sweep target list so it is `("$root/../skills" "$root/../hooks" "$root/../.claude-plugin" "$root/../plan-a-design.md" "$root/../plan-c-refactor.md")` and keep the existing `[ -e "$root/../README.md" ] && sweep_targets+=("$root/../README.md")`. The non-existent `../design.md` and `../docs/playbook` targets are removed; `plan-a-design.md` and the committed spec `plan-c-refactor.md` are added so the long-dash gate covers the canonical and refactor specs and carries no dead target. Also replace the detector on that line, `grep -rlnP '\x{2014}|\x{2013}'`, with two single-codepoint byte scans combined by shell `||`, so the whole conditional reads exactly `if LC_ALL=C grep -rln $'\xe2\x80\x94' "${sweep_targets[@]}" 2>/dev/null || LC_ALL=C grep -rln $'\xe2\x80\x93' "${sweep_targets[@]}" 2>/dev/null; then echo "FAIL: long dash (U+2014 or U+2013) found in shipped/spec surface"; fail=1; else echo "ok: no long dashes"; fi`. BSD grep has no `-P`, so the original `grep -rlnP` form silently never matched on the target machine and the `2>/dev/null` swallowed its usage error, making the gate false-green; a single `LC_ALL=C grep` with a BRE `\|` alternation over multibyte byte-operands is also silently false-green on BSD grep under a C locale (Deviation D4), so the alternation is split into two single-codepoint scans, each of which matches the raw UTF-8 bytes of one long dash soundly on BSD grep under both a C and a UTF-8 locale and on GNU grep. The FAIL and success polarity and message are unchanged.

- [ ] **Step 3: Run the whole suite**

Run: `bash tests/run-all.sh`
Expected: every hook test prints `PASS` lines, `manifests` passes, the long-dash sweep prints `ok: no long dashes`, final exit 0. The skill-triggering line may print `WARN` (needs the `claude` CLI); that is not a failure.

- [ ] **Step 4: Commit**

```bash
git add tests/run-all.sh
git rm -q --cached tests/hooks/test-anchor.sh tests/hooks/test-coverage-supplement.sh tests/hooks/test-context-percent.sh 2>/dev/null || true
git commit -m "refactor: drop rejected-model tests, fix run-all sweep targets"
```

---

### Task 11: Live verification (real session only, not subagent-executable)

**Files:** none changed unless the fallback triggers.

A subagent cannot observe a real compaction or real cross-turn hook delivery (plan-c §9). These checks must be run by a human or by the assistant in a real, non-subagent Claude Code session with the plugin loaded. They gate completion; the refactor is not "done" until they pass or the documented fallback is applied.

- [ ] **Step 1: Stop-sourced injection delivery**

In a real session, end a turn so the `unease` hook fires on `Stop`, then begin the next turn. Confirm the next turn's context contains the unease pulse prompt as a system reminder and that the prior turn ended normally (no forced continuation). Expected: the prompt is visible; the turn terminated.

- [ ] **Step 2: Fallback if Step 1 fails**

If and only if Stop-sourced `additionalContext` is not delivered on the running build: in `hooks/hooks.json` move the `unease` entry from `Stop` to `UserPromptSubmit` (same envelope, same non-blocking property; plan-c §9). Re-run `bash tests/manifests.sh` and `bash tests/hooks/test-unease.sh` (update the test's `hook_event_name` to `UserPromptSubmit`). Commit: `git commit -am "fix: move unease pulse to UserPromptSubmit per live check"`.

- [ ] **Step 3: Which event fires on a real auto-compaction**

Drive context to a real auto-compaction. Confirm the original request is re-injected with primacy afterwards via `PostCompact` or `SessionStart` with `source` `compact` (both are wired; either satisfies the requirement). Expected: the verbatim original request appears ahead of orchestration scaffolding in the post-compaction context.

- [ ] **Step 4: Declared-window survival across compaction**

Confirm that after the compaction the `playbook-window: <integer>` line is still present (preserved by the `PreCompact` steer) or that the agent re-declares it, and that `take-a-beat` still computes a percent. Expected: the beat continues to fire correctly post-compaction.

- [ ] **Step 5: Record the observations**

Append the observed results (build version, which post-compaction event fired, whether Stop delivery worked) to the project memory note, not to any file in the user tree. No commit unless the fallback in Step 2 was applied.

---

## Self-review

Performed against `plan-c-refactor.md` after writing this plan.

**Spec coverage:** plan-c §3 carrier and seam to Tasks 1, 3, 4. §4 unease pulse to Task 2. §5 and §6 context signal and declared window to Tasks 1, 3. §7 inventory: hooks Tasks 2 to 5; helpers Task 1; wiring Task 5; doctrine Task 6; offline-mode Task 7; README and .gitignore Task 8; plan-a-design.md Task 9; tests Tasks 1 to 6 and 10. §8 closure map satisfied by Tasks 1 to 10. §9 live checks to Task 11. §10 no-file clause enforced by the "writes no file" assertions in Tasks 2, 3 and the README rewrite. §11 sanctioned edits scoped in Task 9. §13 constraints carried in the header and the long-dash sweeps.

**Placeholder scan:** no TBD, no "handle edge cases", every code step shows the full file or the exact transformation and the exact assertion. The doc rewrites give exact replacement text for the substantive paragraphs and exact rules for the mechanical sweeps.

**Type and name consistency:** helper names (`playbook_original_request`, `playbook_context_used`, `playbook_declared_window`, `playbook_context_percent`) are defined in Task 1 and used identically in Tasks 3 and 4. The hook file `hooks/unease` and test `tests/hooks/test-unease.sh` names are consistent across Tasks 2, 5, 10. The declared-window sentinel `playbook-window: <integer>` is identical in the helper (Task 1), the hooks (Tasks 3, 4) and the doctrine (Task 6).

One deliberate scope decision flagged for review: Task 10 adds `plan-c-refactor.md` to the long-dash sweep targets (not only the `plan-a-design.md` correction plan-c's run-all bullet names), because the zero-long-dash build constraint governs every shipped or spec file and the committed refactor spec would otherwise be ungated. This is an addition beyond the literal plan-c run-all bullet; the reviewer should confirm it is acceptable.
