#!/usr/bin/env bash
# Where Playbook keeps its files: outside the project and outside ~/.claude, with 2.8's files carried over.
set -uo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0
pass()  { echo "PASS: $1"; }
flunk() { echo "FAIL: $1"; fail=1; }
eq()    { if [ "$2" = "$3" ]; then pass "$1"; else flunk "$1 (expected [$2], got [$3])"; fi }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
lib() { env -u PLAYBOOK_STATE_DIR -u PLAYBOOK_GLOBAL_DIR -u XDG_STATE_HOME HOME="$T/home" "$@" bash -c "source '$root/hooks/lib/playbook-common.sh'; $LIBCMD"; }
mkdir -p "$T/home"

LIBCMD='playbook_state_root'; eq "session state defaults to ~/.local/state/playbook/sessions" "$T/home/.local/state/playbook/sessions" "$(lib)"
LIBCMD='playbook_global_dir'; eq "machine files default to ~/.local/state/playbook" "$T/home/.local/state/playbook" "$(lib)"
LIBCMD='playbook_state_root'; eq "XDG_STATE_HOME is honoured" "$T/xdg/playbook/sessions" "$(lib XDG_STATE_HOME="$T/xdg")"
LIBCMD='playbook_state_root'; eq "PLAYBOOK_STATE_DIR still overrides" "$T/s" "$(lib PLAYBOOK_STATE_DIR="$T/s")"

rm -rf "$T/home"; mkdir -p "$T/home/.claude/playbook/bin" "$T/home/.local/state/playbook"
printf 'ntfy\n' > "$T/home/.claude/playbook/notify-provider"
printf 'old-topic\n' > "$T/home/.claude/playbook/ntfy-topic"
printf 'x\n' > "$T/home/.claude/playbook/bin/statusline"
printf 'new-topic\n' > "$T/home/.local/state/playbook/ntfy-topic"
LIBCMD='playbook_notify_provider /nowhere'; eq "2.8's machine files are carried over" ntfy "$(lib)"
eq "including its subfolders" x "$(cat "$T/home/.local/state/playbook/bin/statusline" 2>/dev/null)"
eq "without overwriting a file already in the new folder" new-topic "$(cat "$T/home/.local/state/playbook/ntfy-topic")"
eq "and the old folder is left as it was" old-topic "$(cat "$T/home/.claude/playbook/ntfy-topic")"
printf 'pushover\n' > "$T/home/.claude/playbook/notify-provider"; rm -f "$T/home/.local/state/playbook/notify-provider"
LIBCMD='playbook_notify_provider /nowhere'; eq "the copy happens once, so a file deleted afterwards stays deleted" "" "$(lib)"

mkdir -p "$T/home/.claude/hook-state/playbook/s1"
printf 'route_mode=hackathon\n' > "$T/home/.claude/hook-state/playbook/s1/state"
LIBCMD='d="$(playbook_live_dir "{\"session_id\":\"s1\"}")"; printf "%s %s" "$d" "$(playbook_state_get "$d" route_mode)"'
eq "a session resumed across the upgrade keeps its state" "$T/home/.local/state/playbook/sessions/s1 hackathon" "$(lib)"

for f in hooks/signal hooks/take-a-beat hooks/session-start hooks/dispatch-guard hooks/team-idle hooks/lib/playbook-common.sh scripts/statusline scripts/install-aliases.sh scripts/notify; do
  if grep -v 'hook-state/playbook/\${sid}\|old="\${HOME}/.claude/playbook"\|2.8 kept' "$root/$f" | grep -q '\.claude/hook-state\|~/\.claude/playbook\|HOME}/\.claude/playbook\|HOME/\.claude/playbook'; then flunk "$f still writes under .claude"; else pass "$f keeps nothing under .claude"; fi
done

exit $fail
