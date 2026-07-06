#!/usr/bin/env bash
# Generates a pristine, Playbook-neutral toy project used as the working tree for
# the repo-operating routing prompts (rename / per-module notes / doc examples).
# Neutral on purpose: a probe must never read Playbook's own mode doctrine and let
# it bias the route. Usage: make-fixture.sh <target-dir>
set -euo pipefail
d="${1:?usage: make-fixture.sh <target-dir>}"
rm -rf "$d"; mkdir -p "$d"/{lib,bin,modules,docs/commands}

cat > "$d/README.md" <<'EOF'
# storekit

A tiny toy toolkit. The core helper is `store_load`, which reads a record file
and hands it to the rest of the app. See `lib/store.sh`.
EOF

cat > "$d/run-tests.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
. "$(dirname "$0")/lib/store.sh"
[ "$(store_load fixtures/one.rec)" = "ONE" ] && echo "ok" || { echo "fail"; exit 1; }
EOF
chmod +x "$d/run-tests.sh"

cat > "$d/lib/store.sh" <<'EOF'
#!/usr/bin/env bash
# store_load: read a record file and echo its upper-cased body.
store_load() {
  local f="$1"
  [ -f "$f" ] || { echo "missing: $f" >&2; return 1; }
  tr '[:lower:]' '[:upper:]' < "$f"
}
EOF

cat > "$d/lib/index.sh" <<'EOF'
#!/usr/bin/env bash
. "$(dirname "$0")/store.sh"
build_index() { for r in "$@"; do echo "$(store_load "$r")"; done; }
EOF

cat > "$d/bin/app.sh" <<'EOF'
#!/usr/bin/env bash
. "$(dirname "$0")/../lib/store.sh"
main() { store_load "${1:-fixtures/one.rec}"; }
main "$@"
EOF

# Eight independent modules, each with its own small, self-contained smell.
cat > "$d/modules/auth.js" <<'EOF'
export function checkToken(t) {
  if (t == null) return false;
  return t.length > 0; // no expiry or signature check
}
EOF
cat > "$d/modules/cache.js" <<'EOF'
const store = {};
export function put(k, v) { store[k] = v; } // unbounded, never evicts
export function get(k) { return store[k]; }
EOF
cat > "$d/modules/parser.js" <<'EOF'
export function parseCSV(s) {
  return s.split("\n").map(r => r.split(",")); // ignores quoted commas
}
EOF
cat > "$d/modules/logger.js" <<'EOF'
export function log(level, msg) {
  console.log(level + ": " + msg); // no timestamp, no level filter
}
EOF
cat > "$d/modules/queue.js" <<'EOF'
const q = [];
export function push(x) { q.push(x); }
export function pop() { return q.pop(); } // LIFO despite the name
EOF
cat > "$d/modules/router.js" <<'EOF'
const routes = [];
export function add(path, fn) { routes.push({ path, fn }); }
export function match(p) { return routes.find(r => r.path === p); } // no params
EOF
cat > "$d/modules/config.js" <<'EOF'
export function load(env) {
  return { debug: env.DEBUG === "true", port: env.PORT || 3000 }; // port stays a string
}
EOF
cat > "$d/modules/validator.js" <<'EOF'
export function isEmail(s) {
  return s.includes("@"); // accepts "@" alone
}
EOF

# Five command docs, each missing a usage example.
for c in init build deploy clean status; do
  cat > "$d/docs/commands/$c.md" <<EOF
# $c

Runs the \`$c\` step of the toolkit.
EOF
done

echo "fixture ready at $d"
