#!/usr/bin/env bash
# Tests for scripts/install-aliases.sh, the bare-command-alias installer.
# Claude Code only ever exposes a plugin command as /playbook:<name>; this
# script writes the standalone ~/.claude/commands/<name>.md files that give the
# plain /<name>. The contract these tests pin: every managed file carries the
# ownership marker, a name already owned by someone else is never clobbered,
# re-running is a safe refresh, and --remove touches only Playbook's own files.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
script="$root/scripts/install-aliases.sh"

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
export PLAYBOOK_COMMANDS_DIR="$sandbox/commands"
export PLAYBOOK_GLOBAL_DIR="$sandbox/playbook"

pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1"; exit 1; }

version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$root/.claude-plugin/plugin.json" | head -1)"

# --- fresh install --------------------------------------------------------

bash "$script" >/dev/null

for name in brainstorming debug fix offline-mode worktrees hello workflow; do
  [ -f "$PLAYBOOK_COMMANDS_DIR/$name.md" ] \
    || die "fresh install did not create /$name"
  grep -q 'playbook-managed' "$PLAYBOOK_COMMANDS_DIR/$name.md" \
    || die "/$name missing the ownership marker"
done
pass "fresh install writes all seven bare aliases, each marked"

# Delegates point at the right skill (short name maps to the *-mode skill).
grep -q 'Invoke the `playbook:fix-mode` skill' "$PLAYBOOK_COMMANDS_DIR/fix.md" \
  && grep -q 'Invoke the `playbook:debug-mode` skill' "$PLAYBOOK_COMMANDS_DIR/debug.md" \
  && grep -q 'Invoke the `playbook:brainstorming` skill' "$PLAYBOOK_COMMANDS_DIR/brainstorming.md" \
  && pass "delegates target the correct skills" \
  || die "a delegate targets the wrong skill"

# Copies mirror the plugin command body (workflow keeps its user-only guard).
grep -q 'disable-model-invocation: true' "$PLAYBOOK_COMMANDS_DIR/workflow.md" \
  || die "workflow copy lost disable-model-invocation"
grep -q '\$ARGUMENTS' "$PLAYBOOK_COMMANDS_DIR/workflow.md" \
  || die "workflow copy lost its \$ARGUMENTS body"
pass "command-backed names are mirrored verbatim, guard intact"

# Manifest records version and the full installed set.
grep -q "version=$version" "$PLAYBOOK_GLOBAL_DIR/aliases" \
  || die "manifest missing version=$version"
grep -q 'installed=brainstorming,debug,fix,offline-mode,worktrees,hello,workflow' \
  "$PLAYBOOK_GLOBAL_DIR/aliases" \
  || die "manifest installed list wrong"
pass "manifest records version and installed set"

# Generated files must stay free of the long dashes the shipped surface bans.
if LC_ALL=C grep -rlq $'\xe2\x80\x94' "$PLAYBOOK_COMMANDS_DIR" 2>/dev/null \
   || LC_ALL=C grep -rlq $'\xe2\x80\x93' "$PLAYBOOK_COMMANDS_DIR" 2>/dev/null; then
  die "a generated alias file contains a long dash"
fi
pass "generated files contain no long dashes"

# --- foreign name is never clobbered --------------------------------------

printf -- '---\ndescription: someone elses debug\n---\nnot playbook\n' \
  > "$PLAYBOOK_COMMANDS_DIR/debug.md"
out="$(bash "$script")"
echo "$out" | grep -q 'SKIPPED /debug' || die "foreign /debug was not skipped"
grep -q 'not playbook' "$PLAYBOOK_COMMANDS_DIR/debug.md" \
  || die "foreign /debug was overwritten"
grep -q 'installed=brainstorming,fix' "$PLAYBOOK_GLOBAL_DIR/aliases" \
  || die "skipped name still recorded as installed"
pass "a foreign command is skipped and preserved, not recorded"

# --- refresh is idempotent and stays owned --------------------------------

rm -f "$PLAYBOOK_COMMANDS_DIR/debug.md"       # drop the foreign file
bash "$script" >/dev/null
out="$(bash "$script")"                        # second clean run
echo "$out" | grep -q 'UPDATED /fix' || die "refresh did not report UPDATED"
grep -q 'playbook-managed' "$PLAYBOOK_COMMANDS_DIR/debug.md" \
  || die "refresh did not re-take the freed /debug name"
pass "refresh is idempotent and re-claims freed names"

# --- remove touches only Playbook's own files -----------------------------

printf -- '---\ndescription: mine\n---\nmine\n' > "$PLAYBOOK_COMMANDS_DIR/fix.md"
bash "$script" >/dev/null                      # fix now foreign-owned again
out="$(bash "$script" --remove)"
echo "$out" | grep -q 'KEPT /fix' || die "--remove clobbered a foreign /fix"
[ -f "$PLAYBOOK_COMMANDS_DIR/fix.md" ] || die "--remove deleted a foreign /fix"
[ ! -f "$PLAYBOOK_COMMANDS_DIR/brainstorming.md" ] \
  || die "--remove left a Playbook-managed alias behind"
grep -q 'removed' "$PLAYBOOK_GLOBAL_DIR/aliases" \
  || die "--remove did not record the removed state"
pass "--remove deletes only managed files and records the state"

echo "ok: install-aliases behaves"
