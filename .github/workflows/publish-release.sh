#!/usr/bin/env bash
#
# Shared "put this leg's artifact on the release" step for fork-release.yml.
# Run from the repository root (GitHub's default working directory), with:
#
#   GH_TOKEN      token with `contents: write`
#   RELEASE_TAG   tag whose release to publish to
#   PUBLISH       "true" to publish, anything else to skip
#   ASSET         path of the file to upload
#   VERSION       Emacs version from configure.ac, used in the release notes
#
# Both legs run this independently and neither waits for the other, so
# creation has to be idempotent: the first leg through creates the release,
# the others find it and just add their asset. That also means a leg can
# publish on its own if the other one fails.

set -eo pipefail

if [ "$PUBLISH" != "true" ]; then
  echo "::notice::manual run without publish_tag - artifact built but not released"
  exit 0
fi

if [ ! -f "$ASSET" ]; then
  echo "::error::asset not found: $ASSET"
  exit 1
fi

if gh release view "$RELEASE_TAG" >/dev/null 2>&1; then
  is_draft="$(gh release view "$RELEASE_TAG" --json isDraft --jq .isDraft)"
  if [ "$is_draft" = "true" ]; then
    # Deleting a tag and pushing it again turns its release into a draft;
    # publish it rather than silently skipping.
    echo "::notice::release $RELEASE_TAG exists as a draft - publishing"
    gh release edit "$RELEASE_TAG" --draft=false
  else
    echo "::notice::release $RELEASE_TAG already exists - only uploading"
  fi
else
  gh release create "$RELEASE_TAG" \
    --title "$RELEASE_TAG" \
    --notes "GNU Emacs $VERSION built from $GITHUB_REPOSITORY.

Commit: $GITHUB_SHA
Build: $GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID" \
    --target "$GITHUB_SHA"
fi

# shellcheck disable=SC2086 # ASSET is quoted, this is just for the log line
echo "::notice::uploading $(basename "$ASSET") to $RELEASE_TAG"
gh release upload "$RELEASE_TAG" "$ASSET" --clobber
