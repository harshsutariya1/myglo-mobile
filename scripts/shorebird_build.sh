#!/usr/bin/env bash
# Builds a Shorebird release or patch and uploads its debug symbols to Sentry.
#
#   scripts/shorebird_build.sh release android
#   scripts/shorebird_build.sh patch ios --release-version=1.0.0+1
#   scripts/shorebird_build.sh release android -- --dart-define=SHOREBIRD_TRACK=staging
#
# Arguments before `--` go to `shorebird release|patch`; arguments after it go
# to the underlying `flutter build`. See docs/releases_and_updates.md.
#
# Needs: shorebird (logged in), SENTRY_AUTH_TOKEN in the environment or an
# untracked sentry.properties, a .env with the production values, and for
# Android an android/key.properties upload key.
set -euo pipefail

usage() {
  echo "Usage: $0 <release|patch> <android|ios> [shorebird args...] [-- flutter build args...]" >&2
  exit 64
}

[[ $# -ge 2 ]] || usage
command="$1"
platform="$2"
shift 2
[[ "$command" == "release" || "$command" == "patch" ]] || usage
[[ "$platform" == "android" || "$platform" == "ios" ]] || usage

cd "$(dirname "$0")/.."

fail() {
  echo "error: $*" >&2
  exit 1
}

# Preflight: catch a missing secret before the long build, not after it.
command -v shorebird >/dev/null || fail "shorebird CLI not found (https://docs.shorebird.dev)."
[[ -f .env ]] || fail ".env is missing; the app can't start without it."
grep -q '^SENTRY_DSN=.\+' .env || echo "warning: SENTRY_DSN is empty in .env; this build won't report errors." >&2
if [[ -z "${SENTRY_AUTH_TOKEN:-}" ]] && ! grep -q '^auth_token=.\+' sentry.properties 2>/dev/null; then
  fail "Set SENTRY_AUTH_TOKEN (or auth_token in the untracked sentry.properties) so symbols can be uploaded."
fi
if [[ "$platform" == "android" && "$command" == "release" && ! -f android/key.properties ]]; then
  fail "android/key.properties is missing; store builds must be signed with the upload key."
fi

# Patches write symbols with the same file names as the release, so start from
# an empty folder and upload straight after each build.
symbols_dir="build/debug-info/$platform"
rm -rf "$symbols_dir"
mkdir -p "$symbols_dir"

shorebird_args=()
flutter_args=()
seen_separator=false
for arg in "$@"; do
  if [[ "$seen_separator" == false && "$arg" == "--" ]]; then
    seen_separator=true
  elif [[ "$seen_separator" == true ]]; then
    flutter_args+=("$arg")
  else
    shorebird_args+=("$arg")
  fi
done
flutter_args+=("--split-debug-info=$symbols_dir")

echo "==> shorebird $command $platform ${shorebird_args[*]:-} -- ${flutter_args[*]}"
shorebird "$command" "$platform" ${shorebird_args[@]+"${shorebird_args[@]}"} -- "${flutter_args[@]}"

echo "==> Uploading debug symbols to Sentry"
dart run sentry_dart_plugin --sentry-define=symbols_path="$symbols_dir"

echo "==> Done. Keep a copy of $symbols_dir if you upload symbols anywhere else."
