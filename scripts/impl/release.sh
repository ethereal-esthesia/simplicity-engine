#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

cd "$ROOT_DIR"

if [[ $# -eq 0 ]]; then
  tag="$(git tag --list 'v*' --sort=-version:refname | head -n 1 || true)"
  if [[ -z "${tag}" ]]; then
    echo "No release tag found."
  else
    echo "$tag"
  fi
  exit 0
fi

if [[ $# -ne 1 ]]; then
  echo "Usage:"
  echo "  ./scripts/release.sh            # show latest release tag"
  echo "  ./scripts/release.sh v0.1.0     # create and push release tag"
  exit 1
fi

new_tag="$1"

if [[ ! "$new_tag" =~ ^v[0-9]+(\.[0-9]+){0,2}([-.][0-9A-Za-z]+)*$ ]]; then
  echo "Invalid release tag: $new_tag"
  echo "Expected a version-style tag like v1.0.0"
  exit 1
fi

if git rev-parse "$new_tag" >/dev/null 2>&1; then
  echo "Tag already exists locally: $new_tag"
  exit 1
fi

if git ls-remote --exit-code --tags origin "refs/tags/$new_tag" >/dev/null 2>&1; then
  echo "Tag already exists on origin: $new_tag"
  exit 1
fi

git tag "$new_tag"
git push origin "$new_tag"

echo "Created and pushed release tag: $new_tag"
