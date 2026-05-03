#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
usage: ./tests/commit-step.sh "commit message" -- path [path ...]

Stages only the listed paths, creates one commit, then pushes the current branch
to origin. Existing staged changes outside the listed paths cause an abort.
USAGE
}

if [ "$#" -lt 3 ] || [ "${2:-}" != "--" ]; then
  usage
  exit 2
fi

message="$1"
shift 2

if [ -z "$message" ]; then
  echo "commit message must not be empty" >&2
  exit 2
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

branch="$(git branch --show-current)"
if [ -z "$branch" ]; then
  echo "cannot push from a detached HEAD" >&2
  exit 2
fi

before_staged="$(git diff --cached --name-only)"
if [ -n "$before_staged" ]; then
  for staged_path in $before_staged; do
    matched=0
    for allowed_path in "$@"; do
      if [ "$staged_path" = "$allowed_path" ] || [[ "$staged_path" == "$allowed_path/"* ]]; then
        matched=1
        break
      fi
    done
    if [ "$matched" -eq 0 ]; then
      echo "refusing to commit unrelated staged path: $staged_path" >&2
      exit 2
    fi
  done
fi

git add -- "$@"

if git diff --cached --quiet -- "$@"; then
  echo "no staged changes for requested paths" >&2
  exit 2
fi

git commit -m "$message" -- "$@"
git push -u origin "$branch"
