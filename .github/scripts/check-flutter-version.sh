#!/usr/bin/env bash
# Verifies that `.fvmrc` still pins an exact Flutter release.
#
# `.fvmrc` is the only place the Flutter version is written. Both workflows read
# it through subosito/flutter-action's `flutter-version-file` input, which
# resolves the file with `jq -r '.flutter'`.
#
# This check exists because of how that resolution fails. When the file cannot
# be read, the action ends up with an empty version, and an empty version is
# treated as `any`: it installs whatever stable happens to be that day. Nothing
# goes red. CI simply stops being pinned, which is the condition HIT-086 was
# opened to remove, and the first sign of it would be an unrelated pull request
# failing on an SDK nobody chose.
#
# One copy of a version cannot drift from itself, but it can still be broken.
# This turns that break into a failure with a name.
#
# It lives in a file rather than inline in a workflow because both flutter_ci
# and release_validation need it, and a check against duplication should not be
# written down twice. release_validation also runs on `v*` tags, and a tag can
# be created on any commit, including one that never went through flutter_ci.
set -euo pipefail

file="${1:-.fvmrc}"

if [ ! -f "$file" ]; then
  echo "::error::$file is missing. Both workflows read the Flutter version from it."
  exit 1
fi

# One pass over the file. `.flutter` on its own would abort with jq's own
# "Cannot index array with string" when the file holds something that is not an
# object, and that message says nothing about what to fix; guarding on `type`
# keeps every wrong shape on the same path as a wrong value, which the next
# check reports properly.
if ! version="$(jq -r 'if type == "object" then (.flutter // empty) else empty end' "$file" 2>/dev/null)"; then
  echo "::error file=$file::$file is not valid JSON. The setup action cannot read it, and an unreadable file un-pins the SDK without failing."
  exit 1
fi

# An exact release, not a channel. `stable` parses, resolves to "latest", and
# would leave CI unpinned while looking deliberate. A pre-release such as
# 3.48.0-1.2.pre is rejected on purpose: this project tracks stable, and
# widening the shape is a decision worth making here rather than discovering in
# a build.
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "::error file=$file::Expected an exact stable version such as 3.47.0 under the \"flutter\" key, found '${version:-nothing}'."
  exit 1
fi

echo "Flutter is pinned to $version by $file."
