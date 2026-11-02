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
else
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
  [ "$fail" -eq 0 ] && echo "PASS: $checked docs/ reference(s) from skills resolve to real headings"
fi

for ref in $(grep -rhoE 'playbook:[a-z][a-z-]+' "$root/skills" "$root/commands" "$root/README.md" 2>/dev/null | sort -u); do
  name="${ref#playbook:}"
  if [ -f "$root/skills/$name/SKILL.md" ] || [ -f "$root/commands/$name.md" ]; then
    echo "PASS: $ref resolves to a skill or command"
  else
    echo "FAIL: $ref is referenced but no skills/$name or commands/$name.md exists"
    fail=1
  fi
done

for path in $(grep -rhoE '(^|[^A-Za-z/._-])scripts/[a-z][a-z.-]*' "$root/skills" "$root/commands" "$root/README.md" 2>/dev/null | sed -E 's/^[^s]*//' | sort -u); do
  if [ -e "$root/$path" ]; then
    echo "PASS: $path exists"
  else
    echo "FAIL: $path is referenced from the docs but does not exist"
    fail=1
  fi
done

channel='route goal unease decision rethink weigh done interface publish part-done waiting aligned resume status help'
taught="$(grep -rhoE '`(: )?playbook [a-z-]+' "$root/skills" "$root/commands" "$root/README.md" | sed -E 's/^`(: )?playbook //' | sort -u)"
[ -n "$taught" ] && echo "PASS: the docs teach playbook commands, so the check below has something to check" || { echo "FAIL: no playbook commands found in the docs"; fail=1; }
for verb in $taught; do
  case " $channel " in
    *" $verb "*) echo "PASS: 'playbook $verb' is a channel command" ;;
    *) echo "FAIL: 'playbook $verb' is taught but is not a channel command"; fail=1 ;;
  esac
done

for f in "$root"/skills/*/SKILL.md; do
  d="$(basename "$(dirname "$f")")"
  if grep -q "^name: $d\$" "$f"; then
    echo "PASS: skills/$d frontmatter name matches its directory"
  else
    echo "FAIL: skills/$d frontmatter name does not match its directory"
    fail=1
  fi
done

if [ -e "$root/skills/time-rule" ] || grep -rqi 'playbook:time-rule' "$root/skills" "$root/commands" "$root/README.md"; then
  echo "FAIL: the time rule is still referenced or present"
  fail=1
else
  echo "PASS: no reference to the deleted time-rule skill"
fi

exit $fail
