#!/usr/bin/env bash
# Fixture: a throwaway git repo with a programme, plus assertion helpers.
set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PLUGIN_ROOT
TESTS_RUN=0
TESTS_FAILED=0

# XDG_STATE_HOME MUST live outside the repo under test. The hooks write per-session state files
# there, and a state directory inside the tree shows up in `git status --porcelain` as untracked
# changes — the guard then fires on its own bookkeeping. Measured: putting it at "$REPO/.state"
# makes the docs-only and top-level-.md cases fail for entirely the wrong reason.
#
# Assigned here at source time, NOT inside make_repo: make_repo is called as `REPO=$(make_repo)`,
# which runs in a command-substitution subshell, so an export inside it never reaches the caller.
STATE_HOME=$(mktemp -d)
export STATE_HOME XDG_STATE_HOME="$STATE_HOME"

make_repo() {
  local dir
  dir=$(mktemp -d)
  git -C "$dir" init -q
  git -C "$dir" config user.email t@example.com
  git -C "$dir" config user.name Test
  mkdir -p "$dir/src"
  echo "initial" >"$dir/src/app.ts"
  git -C "$dir" add -A
  git -C "$dir" commit -qm "init"
  printf '%s' "$dir"
}

# Appends a row rather than rewriting INDEX.md — two programmes must be able to coexist, which is
# the whole point of branch-based resolution.
add_programme() {
  local dir=$1 slug=$2 branch=$3
  mkdir -p "$dir/docs/programmes/$slug/archive"
  if [ ! -f "$dir/docs/programmes/INDEX.md" ]; then
    cat >"$dir/docs/programmes/INDEX.md" <<'EOF'
# Programmes

| programme | status | branch | ledger |
| --------- | ------ | ------ | ------ |
EOF
  fi
  printf '| %s | active | %s | programmes/%s/ledger.md |\n' "$slug" "$branch" "$slug" \
    >>"$dir/docs/programmes/INDEX.md"
  cat >"$dir/docs/programmes/$slug/ledger.md" <<'EOF'
# Test — programme ledger

## The arc

<!-- Rows marked (example) are seeded illustrations — /programme:init deletes them. -->

**Goal:** The goal line.

| phase         | status  | what it delivers          |
| ------------- | ------- | ------------------------- |
| 1 — the slice | current | the goal line, end to end |

## Current position — 2026-08-12 (TESTING)

The position line.

## Settled decisions

## Open forks

## Archive index
EOF
}

# run_hook <script> <json-stdin> [cwd] ; captures OUT, ERR, RC
run_hook() {
  local script=$1 payload=$2 cwd=${3:-$PWD}
  local tmp_out tmp_err
  tmp_out=$(mktemp); tmp_err=$(mktemp)
  set +e
  (cd "$cwd" && CLAUDE_PROJECT_DIR="$cwd" bash "$PLUGIN_ROOT/hooks/$script") \
    <<<"$payload" >"$tmp_out" 2>"$tmp_err"
  RC=$?
  set -e
  OUT=$(cat "$tmp_out"); ERR=$(cat "$tmp_err")
  rm -f "$tmp_out" "$tmp_err"
}

payload() {
  # payload <event> <session_id> [source]
  printf '{"session_id":"%s","cwd":"%s","hook_event_name":"%s","source":"%s"}' \
    "$2" "$PWD" "$1" "${3:-startup}"
}

assert_eq() {
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$1" = "$2" ]; then printf '  ok   %s\n' "$3"; else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  FAIL %s\n       expected: %s\n       actual:   %s\n' "$3" "$1" "$2"
  fi
}

assert_contains() {
  TESTS_RUN=$((TESTS_RUN + 1))
  case "$1" in
    *"$2"*) printf '  ok   %s\n' "$3" ;;
    *)
      TESTS_FAILED=$((TESTS_FAILED + 1))
      printf '  FAIL %s\n       %s\n       not found in: %s\n' "$3" "$2" "$1"
      ;;
  esac
}

assert_not_contains() {
  TESTS_RUN=$((TESTS_RUN + 1))
  case "$1" in
    *"$2"*)
      TESTS_FAILED=$((TESTS_FAILED + 1))
      printf '  FAIL %s\n       %s\n       found in: %s\n' "$3" "$2" "$1"
      ;;
    *) printf '  ok   %s\n' "$3" ;;
  esac
}

assert_empty() {
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -z "$1" ]; then printf '  ok   %s\n' "$2"; else
    TESTS_FAILED=$((TESTS_FAILED + 1))
    printf '  FAIL %s\n       expected empty, got: %s\n' "$2" "$1"
  fi
}

finish() {
  printf '\n%d run, %d failed\n' "$TESTS_RUN" "$TESTS_FAILED"
  [ "$TESTS_FAILED" -eq 0 ]
}
