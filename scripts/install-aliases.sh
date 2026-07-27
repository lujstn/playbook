#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
plugin_root="$(cd "$script_dir/.." && pwd)"

commands_dir="${PLAYBOOK_COMMANDS_DIR:-$HOME/.claude/commands}"
global_dir="${PLAYBOOK_GLOBAL_DIR:-$HOME/.claude/playbook}"
manifest="$global_dir/aliases"
marker="playbook-managed"

version="$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  "$plugin_root/.claude-plugin/plugin.json" 2>/dev/null | head -1)"
[ -n "$version" ] || version="unknown"

delegates=(
  "brainstorming|brainstorming|Playbook brainstorming mode: explore deeply, surface sharp questions, then converge."
  "debug|debug-mode|Playbook debug mode: systematic investigation of an unknown failure."
  "fix|fix-mode|Playbook fix mode: focused repair of a known broken thing."
  "offline-mode|offline-mode|Playbook offline mode: enable push notifications for long-running sessions."
  "worktrees|worktrees|Playbook worktrees mode: isolate separate Claude Code sessions in .worktrees/, each on its own branch with an instance number for collision-free resources."
)
copies=(hello workflow review-panel)

owned_by_playbook() { [ -e "$1" ] && grep -q "$marker" "$1"; }

installed_names=""
record_installed() { installed_names="${installed_names:+$installed_names,}$1"; }

write_delegate() {
  local name="$1" skill="$2" desc="$3" dest="$commands_dir/$name.md"
  if [ -e "$dest" ] && ! owned_by_playbook "$dest"; then
    echo "SKIPPED /$name (a non-Playbook command already owns this name; /playbook:$name still works)"
    return
  fi
  local verb="INSTALLED"; [ -e "$dest" ] && verb="UPDATED"
  cat > "$dest" <<EOF
---
description: $desc
---

Invoke the \`playbook:$skill\` skill.

<!-- $marker alias (v$version): bare /$name maps to the playbook:$skill skill; /playbook:$name works too. Refresh or remove via /playbook:setup. -->
EOF
  record_installed "$name"
  echo "$verb /$name -> playbook:$skill"
}

write_copy() {
  local name="$1" src="$plugin_root/commands/$name.md" dest="$commands_dir/$name.md"
  if [ ! -f "$src" ]; then
    echo "MISSING commands/$name.md in the plugin (skipped)"
    return
  fi
  if [ -e "$dest" ] && ! owned_by_playbook "$dest"; then
    echo "SKIPPED /$name (a non-Playbook command already owns this name; /playbook:$name still works)"
    return
  fi
  local verb="INSTALLED"; [ -e "$dest" ] && verb="UPDATED"
  {
    cat "$src"
    printf '\n<!-- %s alias (v%s): bare /%s mirrors /playbook:%s. Refresh or remove via /playbook:setup. -->\n' \
      "$marker" "$version" "$name" "$name"
  } > "$dest"
  record_installed "$name"
  echo "$verb /$name (mirrors /playbook:$name)"
}

remove_one() {
  local name="$1" dest="$commands_dir/$name.md"
  if owned_by_playbook "$dest"; then
    rm -f "$dest"
    echo "REMOVED /$name"
  elif [ -e "$dest" ]; then
    echo "KEPT /$name (not managed by Playbook)"
  fi
}

all_names() {
  local entry
  for entry in "${delegates[@]}"; do printf '%s\n' "${entry%%|*}"; done
  printf '%s\n' "${copies[@]}"
}

if [ "${1:-}" = "--remove" ]; then
  while IFS= read -r name; do remove_one "$name"; done < <(all_names)
  mkdir -p "$global_dir"
  printf 'removed\n' > "$manifest"
  echo "Done. The /playbook:<name> forms are unaffected."
  exit 0
fi

mkdir -p "$commands_dir" "$global_dir"
for entry in "${delegates[@]}"; do
  IFS='|' read -r name skill desc <<< "$entry"
  write_delegate "$name" "$skill" "$desc"
done
for name in "${copies[@]}"; do
  write_copy "$name"
done

{
  printf 'version=%s\n' "$version"
  printf 'installed=%s\n' "$installed_names"
} > "$manifest"

echo "Done. Bare aliases written to $commands_dir; refresh anytime with /playbook:setup."
