#!/usr/bin/env bash
# Cross-reference guard: every docs/<file>.md(#<anchor>)? link referenced
# from a SKILL.md must resolve to a real docs file and, when an anchor is
# given, to a real heading in that file (matched via GitHub-style slugs).
# This is the permanent fix for the kind of section-number drift the
# DESIGN.md split removed; if a docs file moves or a heading is renamed,
# this test fails before the skill ships out of sync.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0

# GitHub-style heading slug for ASCII headings: lowercase, strip anything
# that is not a letter, digit, space or dash, then collapse spaces to
# dashes. Matches the anchors GitHub generates for our docs headings.
slugify() {
  awk '{
    s = tolower($0)
    gsub(/[^a-z0-9 -]/, "", s)
    gsub(/^ +| +$/, "", s)
    gsub(/ +/, "-", s)
    print s
  }' <<<"${1:-}"
}

anchors_in() {
  local f="$1"
  # Every heading line, slugified, one per line.
  awk '/^#+ /{ sub(/^#+[[:space:]]+/, ""); print }' "$f" \
    | while IFS= read -r h; do slugify "$h"; done
}

# Match docs/<file>.md and an optional #<anchor>. Anchors allow mixed case
# defensively even though our convention is lowercase; the resolver below
# does an exact, case-sensitive comparison against the slug set.
linkre='docs/[a-z0-9_-]+\.md(#[a-zA-Z0-9_-]+)?'

refs=()
while IFS= read -r r; do
  [ -n "$r" ] && refs+=("$r")
done < <(grep -rohE "$linkre" "$root/skills" 2>/dev/null | sort -u)

if [ "${#refs[@]}" -eq 0 ]; then
  echo "PASS: no docs/ references in skills (vacuous)"
  exit 0
fi

checked=0
for ref in "${refs[@]}"; do
  file="${ref%%#*}"
  anchor=""
  [[ "$ref" == *"#"* ]] && anchor="${ref#*#}"
  path="$root/$file"
  if [ ! -f "$path" ]; then
    echo "FAIL: missing docs file referenced from skills: $file"
    fail=1
    continue
  fi
  if [ -n "$anchor" ]; then
    # Capture into a variable first; piping straight into `grep -Fxq` under
    # `set -o pipefail` would trip on grep's early-exit SIGPIPE killing the
    # upstream and surfacing a false miss.
    available="$(anchors_in "$path")"
    if ! grep -Fxq "$anchor" <<<"$available"; then
      echo "FAIL: missing anchor #$anchor in $file"
      printf '%s\n' "$available" | sed 's/^/  available: /' >&2
      fail=1
      continue
    fi
  fi
  checked=$((checked + 1))
done

if [ "$fail" -eq 0 ]; then
  echo "PASS: $checked docs/ reference(s) from skills resolve to real headings"
fi
exit $fail
