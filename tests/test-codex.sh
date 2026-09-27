#!/usr/bin/env bash
# Install the local marketplace in an isolated Codex home, then use the
# installed plugin against a new repository. No user-owned skills are touched.
set -uo pipefail
cd "$(dirname "$0")/.."
. tests/lib.sh
ROOT="$(pwd)"
assert_eq 'Codex manifest ships with the source package' 0 \
  "$([[ -f .codex-plugin/plugin.json ]] && echo 0 || echo 1)"

if ! command -v codex >/dev/null 2>&1; then
  echo 'codex CLI unavailable; local install exercise skipped'
  summary
  exit $?
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
export CODEX_HOME="$work/codex"
mkdir -p "$CODEX_HOME"

out="$(codex plugin marketplace add "$ROOT" 2>&1)"; rc=$?
assert_rc 'Codex adds the local marketplace' 0 "$rc"
if [[ "$rc" -ne 0 ]]; then summary; exit 1; fi

out="$(codex plugin add floppy@floppy 2>&1)"; rc=$?
assert_rc 'Codex installs floppy from that marketplace' 0 "$rc"
if [[ "$rc" -ne 0 ]]; then summary; exit 1; fi

installed="$(find "$CODEX_HOME/plugins" -path '*/skills/start/SKILL.md' -print -quit 2>/dev/null)"
assert_eq 'the installed package contains the start skill' 0 "$([[ -n "$installed" ]] && echo 0 || echo 1)"
if [[ -z "$installed" ]]; then summary; exit 1; fi
plugin="${installed%/skills/start/SKILL.md}"
assert_eq 'installed package has a Codex manifest' 0 \
  "$([[ -f "$plugin/.codex-plugin/plugin.json" ]] && echo 0 || echo 1)"

repo="$work/project"
mkdir -p "$repo"
git -C "$repo" init -q -b main
out="$(bash "$plugin/scripts/init.sh" --repo "$repo" --memory-dir .agent-memory --language en 2>&1)"; rc=$?
assert_rc 'installed init prepares a fresh repository' 0 "$rc"
assert_eq 'init writes the memory index' 0 "$([[ -f "$repo/.agent-memory/MEMORY.md" ]] && echo 0 || echo 1)"

out="$(cd "$repo" && bash "$plugin/scripts/run" status 2>&1)"; rc=$?
assert_rc 'installed workstatus dispatcher runs' 0 "$rc"
assert_contains 'workstatus identifies the project' "repo: $repo" "$out"

out="$(cd "$repo" && bash "$plugin/scripts/run" lock acquire codex-test 2>&1)"; rc=$?
assert_rc 'installed wrap lock can be acquired' 0 "$rc"
out="$(cd "$repo" && bash "$plugin/scripts/run" lock release 2>&1)"; rc=$?
assert_rc 'installed wrap lock can be released' 0 "$rc"

summary
