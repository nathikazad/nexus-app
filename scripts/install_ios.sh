#!/usr/bin/env bash
# Build and install a signed release app directly on a paired iPhone.
set -euo pipefail
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mobile_root="$(cd "$script_dir/.." && pwd)"
source "$script_dir/ios_build_config.sh"
usage() {
  cat <<'HELP'
Usage: scripts/install_ios.sh APP --device DEVICE_ID [--dry-run] -- [Flutter build options]
Example: scripts/install_ios.sh nx_main --device YOUR_IPHONE_UDID -- --build-number 2026100702
FLUTTER_BIN may select a standard Flutter SDK. Defaults to flutter on PATH.
No clean, archive, IPA export, Shorebird upload, or uninstall is performed.
HELP
}
if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then usage; exit 0; fi
app="${1:-}"
case "$app" in
  nx_books|nx_hypnosis|nx_cards|nx_cooking|nx_expense|nx_main|nx_docs|nx_people|nx_post|nx_projects|nx_time) ;;
  *) usage >&2; exit 2 ;;
esac
shift
device=''
dry_run=0
while (($#)); do
  case "$1" in
    --device) [[ $# -ge 2 ]] || { usage >&2; exit 2; }; device="$2"; shift 2 ;;
    --dry-run) dry_run=1; shift ;;
    --) shift; break ;;
    *) usage >&2; exit 2 ;;
  esac
done
[[ -n "$device" ]] || { echo 'An explicit --device is required.' >&2; exit 2; }
for arg in "$@"; do
  case "$arg" in
    --debug|--profile|--no-codesign|--simulator|--config-only|--no-release)
      echo "Unsupported option for a signed physical release: $arg" >&2; exit 2 ;;
  esac
done
flutter_bin="${FLUTTER_BIN:-flutter}"
flutter_path="$(command -v "$flutter_bin")" || { echo 'Set FLUTTER_BIN to your standard Flutter executable.' >&2; exit 1; }
case "$flutter_path" in *shorebird*) echo 'Use a standard Flutter SDK, not the Shorebird SDK.' >&2; exit 2;; esac
build_args=(build ios --release)
if requires_openai_key "$app"; then
  require_openai_env
  build_args+=(--dart-define-from-file=../nx_modules/nx_live_agent/.env)
fi
if ((dry_run)); then
  printf 'App: %s\nDevice: %s\nFlutter: %s\n' "$app" "$device" "$flutter_path"
  echo 'Plan: build ios --release, verify signature, install .app, verify version, launch.'
  echo 'Extra build arguments are forwarded unchanged (values omitted).'
  exit 0
fi
cd "$mobile_root/$app"
started=$SECONDS
"$flutter_path" "${build_args[@]}" "$@"
built=$SECONDS
bundle="$PWD/build/ios/iphoneos/Runner.app"
[[ -d "$bundle" ]] || { echo "Missing built app: $bundle" >&2; exit 1; }
codesign --verify --deep --strict "$bundle"
bundle_id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$bundle/Info.plist")
version=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$bundle/Info.plist")
build=$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$bundle/Info.plist")
xcrun devicectl device install app --device "$device" "$bundle" --timeout 120
scratch_root="${NEXUS_SCRATCH_DIR:-$HOME/Projects/Nexus/tmp}"
mkdir -p "$scratch_root/ios-install"
receipt=$(mktemp "$scratch_root/ios-install/installed.XXXXXX")
xcrun devicectl device info apps --device "$device" --json-output "$receipt" --timeout 30
python3 - "$receipt" "$bundle_id" "$version" "$build" <<'PY'
import json, sys
with open(sys.argv[1]) as stream:
    apps = json.load(stream)['result']['apps']
match = next((app for app in apps if app.get('bundleIdentifier') == sys.argv[2]), None)
if not match or str(match.get('version')) != sys.argv[3] or str(match.get('bundleVersion')) != sys.argv[4]:
    raise SystemExit('Installed version verification failed; inspect the saved receipt.')
print(f'Verified {sys.argv[2]} {sys.argv[3]}+{sys.argv[4]}')
PY
xcrun devicectl device process launch --device "$device" --terminate-existing "$bundle_id" --timeout 30
printf 'Build: %ss; install/verify/launch: %ss\nReceipt: %s\n' "$((built-started))" "$((SECONDS-built))" "$receipt"
