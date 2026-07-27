#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
fail=0

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
  awk '/^#+ /{ sub(/^#+[[:space:]]+/, ""); print }' "$f" \
    | while IFS= read -r h; do slugify "$h"; done
}

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
