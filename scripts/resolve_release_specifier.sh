#!/usr/bin/env bash
# Print the one semver specifier shared by parable-bloom, parable-bloom-site,
# and level-builder. An explicit override is echoed unchanged. With no
# override, conventional commits since the latest stable v* tag on HEAD decide:
# feat! or a BREAKING CHANGE footer is major, feat is minor, and any other
# commit is patch. Prints "none" when that tag already points at HEAD.

set -euo pipefail

if [ "${1:-}" != "" ]; then
  printf '%s\n' "$1"
  exit 0
fi

latest=""
while IFS= read -r tag; do
  if printf '%s\n' "$tag" | grep -Eq '^v[0-9]+\.[0-9]+\.[0-9]+$' \
    && git merge-base --is-ancestor "$tag" HEAD; then
    latest=$tag
    break
  fi
done < <(git tag -l 'v*' --sort=-v:refname)

if [ -n "$latest" ]; then
  range="${latest}..HEAD"
else
  range="HEAD"
fi

if [ "$(git rev-list --count "$range")" = "0" ]; then
  printf 'none\n'
  exit 0
fi

if git log "$range" --format='%s' | grep -Eq '^[a-zA-Z]+(\([^)]*\))?!:'; then
  printf 'major\n'
  exit 0
fi

if git log "$range" --format='%b' | grep -Eq '^BREAKING CHANGE:|^BREAKING-CHANGE:'; then
  printf 'major\n'
  exit 0
fi

if git log "$range" --format='%s' | grep -Eq '^feat(\([^)]*\))?:'; then
  printf 'minor\n'
  exit 0
fi

printf 'patch\n'
