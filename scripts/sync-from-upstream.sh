#!/usr/bin/env bash
# Sync olcrtc-linux-amd64 / olcrtc-linux-arm64 from upstream Actions artifact
# into a single GitHub Release tagged "latest".
set -euo pipefail

UPSTREAM_REPO="${UPSTREAM_REPO:-openlibrecommunity/olcrtc}"
MIRROR_REPO="${MIRROR_REPO:-bypassnik/olcrtc-binaries}"
ARTIFACT_NAME="${ARTIFACT_NAME:-olcrtc-cli-binaries}"
RELEASE_TAG="${RELEASE_TAG:-latest}"
AMD64_NAME="olcrtc-linux-amd64"
ARM64_NAME="olcrtc-linux-arm64"

# GITHUB_TOKEN of the mirror repo cannot download Actions artifacts from another repo.
# Prefer UPSTREAM_TOKEN (PAT with public_repo / actions:read); fall back to GH_TOKEN.
UPSTREAM_GH_TOKEN="${UPSTREAM_TOKEN:-${GH_TOKEN:-}}"
MIRROR_GH_TOKEN="${GH_TOKEN:-${UPSTREAM_TOKEN:-}}"
[ -n "$UPSTREAM_GH_TOKEN" ] || { echo "Need UPSTREAM_TOKEN or GH_TOKEN" >&2; exit 1; }
[ -n "$MIRROR_GH_TOKEN" ] || { echo "Need GH_TOKEN for mirror releases" >&2; exit 1; }

gh_upstream() {
  GH_TOKEN="$UPSTREAM_GH_TOKEN" gh "$@"
}

gh_mirror() {
  GH_TOKEN="$MIRROR_GH_TOKEN" gh "$@"
}

workdir=$(mktemp -d)
trap 'rm -rf "$workdir"' EXIT

echo "==> Looking up latest ${ARTIFACT_NAME} on ${UPSTREAM_REPO} (master/main)..."

# Prefer artifacts from default branches; take newest non-expired.
mapfile -t artifact_lines < <(
  gh_upstream api "repos/${UPSTREAM_REPO}/actions/artifacts?name=${ARTIFACT_NAME}&per_page=50" \
    --jq '.artifacts[] | select(.expired == false) | select(.workflow_run.head_branch == "master" or .workflow_run.head_branch == "main") | [.id, .workflow_run.head_sha, .created_at, .size_in_bytes] | @tsv'
)

if [ "${#artifact_lines[@]}" -eq 0 ] || [ -z "${artifact_lines[0]:-}" ]; then
  echo "No non-expired ${ARTIFACT_NAME} artifacts on master/main" >&2
  exit 1
fi

# API returns newest-first; first line is the candidate.
IFS=$'\t' read -r artifact_id source_sha created_at size_bytes <<<"${artifact_lines[0]}"
short_sha=$(printf '%s' "$source_sha" | cut -c1-12)

echo "Selected artifact_id=${artifact_id} sha=${short_sha} created=${created_at} size=${size_bytes}"

current_sha=""
if gh_mirror release view "$RELEASE_TAG" --repo "$MIRROR_REPO" >/dev/null 2>&1; then
  current_sha=$(gh_mirror release view "$RELEASE_TAG" --repo "$MIRROR_REPO" --json name -q .name 2>/dev/null || true)
  # name is short SHA; also accept body SOURCE_SHA=...
  if [ -z "$current_sha" ] || [ "$current_sha" = "null" ]; then
    body=$(gh_mirror release view "$RELEASE_TAG" --repo "$MIRROR_REPO" --json body -q .body 2>/dev/null || true)
    current_sha=$(printf '%s' "$body" | sed -n 's/^SOURCE_SHA=//p' | head -n1)
  fi
fi

if [ -n "$current_sha" ] && { [ "$current_sha" = "$short_sha" ] || [ "$current_sha" = "$source_sha" ]; }; then
  echo "Already up to date (SOURCE_SHA=${current_sha}). Nothing to do."
  exit 0
fi

echo "==> Downloading artifact ${artifact_id}..."
gh_upstream api "repos/${UPSTREAM_REPO}/actions/artifacts/${artifact_id}/zip" > "$workdir/artifact.zip"

echo "==> Extracting..."
unzip -q -o "$workdir/artifact.zip" -d "$workdir/out"

amd64=$(find "$workdir/out" -type f -name "$AMD64_NAME" | head -n1)
arm64=$(find "$workdir/out" -type f -name "$ARM64_NAME" | head -n1"

if [ -z "$amd64" ] || [ -z "$arm64" ]; then
  echo "Missing binaries in artifact. Contents:" >&2
  find "$workdir/out" -type f | head -n50 >&2
  exit 1
fi

chmod +x "$amd64" "$arm64"
cp -f "$amd64" "$workdir/$AMD64_NAME"
cp -f "$arm64" "$workdir/$ARM64_NAME"

printf '%s\n' "$short_sha" > "$workdir/SOURCE_SHA"

notes=$(cat <<EOF
Mirrored from \`${UPSTREAM_REPO}\` Actions artifact \`${ARTIFACT_NAME}\`.

SOURCE_SHA=${short_sha}
SOURCE_SHA_FULL=${source_sha}
ARTIFACT_ID=${artifact_id}
CREATED_AT=${created_at}

Only the latest build is kept in this repository.
EOF
)

echo "==> Publishing release ${RELEASE_TAG} (name=${short_sha})..."

if gh_mirror release view "$RELEASE_TAG" --repo "$MIRROR_REPO" >/dev/null 2>&1; then
  # Replace assets: delete old files then upload fresh ones.
  for asset in "$AMD64_NAME" "$ARM64_NAME" "SOURCE_SHA"; do
    gh_mirror release delete-asset "$RELEASE_TAG" "$asset" --repo "$MIRROR_REPO" --yes 2>/dev/null || true
  done
  gh_mirror release edit "$RELEASE_TAG" --repo "$MIRROR_REPO" --title "$short_sha" --notes "$notes"
  gh_mirror release upload "$RELEASE_TAG" \
    "$workdir/$AMD64_NAME" \
    "$workdir/$ARM64_NAME" \
    "$workdir/SOURCE_SHA" \
    --repo "$MIRROR_REPO" \
    --clobber
else
  gh_mirror release create "$RELEASE_TAG" \
    "$workdir/$AMD64_NAME" \
    "$workdir/$ARM64_NAME" \
    "$workdir/SOURCE_SHA" \
    --repo "$MIRROR_REPO" \
    --title "$short_sha" \
    --notes "$notes" \
    --latest
fi

echo "Done. Release ${RELEASE_TAG} → ${short_sha}"
