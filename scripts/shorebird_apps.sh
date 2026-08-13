#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Manage local, iOS-only Shorebird releases and patches for Nexus Flutter apps.

Usage:
  scripts/shorebird_apps.sh doctor
  scripts/shorebird_apps.sh list
  scripts/shorebird_apps.sh init APP|all
  scripts/shorebird_apps.sh release APP [shorebird arguments...]
  scripts/shorebird_apps.sh patch APP|changed [shorebird arguments...]
  scripts/shorebird_apps.sh preview APP [shorebird arguments...]
  scripts/shorebird_apps.sh affected [git base]

Examples:
  scripts/shorebird_apps.sh release nx_cards
  scripts/shorebird_apps.sh init nx_docs
  scripts/shorebird_apps.sh release nx_docs
  scripts/shorebird_apps.sh patch nx_docs
  scripts/shorebird_apps.sh preview nx_docs
  scripts/shorebird_apps.sh affected HEAD~1
  scripts/shorebird_apps.sh patch changed --allow-asset-diffs

Environment:
  SHOREBIRD_BIN  Shorebird executable. Defaults to shorebird on PATH, then
                 ~/.shorebird/bin/shorebird.

This wrapper intentionally supports iOS only. Shorebird releases and patches
remain interactive unless Shorebird arguments make them non-interactive.
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mobile_root="$(cd "$script_dir/.." && pwd)"

apps=(
  nx_books
  nx_cards
  nx_cooking
  nx_expense
  nx_main
  nx_docs
  nx_people
  nx_post
  nx_projects
  nx_time
)

display_name_for() {
  case "$1" in
    nx_books) printf 'Nexus Books' ;;
    nx_cards) printf 'Nexus Cards' ;;
    nx_cooking) printf 'Nexus Cooking' ;;
    nx_expense) printf 'Nexus Expense' ;;
    nx_main) printf 'Nexus' ;;
    nx_docs) printf 'Nexus Docs' ;;
    nx_people) printf 'Nexus People' ;;
    nx_post) printf 'Nexus Post' ;;
    nx_projects) printf 'Nexus Projects' ;;
    nx_time) printf 'Nexus Time' ;;
    *) return 1 ;;
  esac
}

is_app() {
  local candidate="$1"
  local app
  for app in "${apps[@]}"; do
    [[ "$candidate" == "$app" ]] && return 0
  done
  return 1
}

require_app() {
  if ! is_app "$1"; then
    printf 'Unknown Nexus app: %s\n\n' "$1" >&2
    usage >&2
    exit 2
  fi
}

resolve_shorebird() {
  if [[ -n "${SHOREBIRD_BIN:-}" ]]; then
    printf '%s' "$SHOREBIRD_BIN"
  elif command -v shorebird >/dev/null 2>&1; then
    command -v shorebird
  elif [[ -x "$HOME/.shorebird/bin/shorebird" ]]; then
    printf '%s' "$HOME/.shorebird/bin/shorebird"
  else
    printf 'Shorebird is not installed or is not on PATH.\n' >&2
    exit 1
  fi
}

shorebird_bin="$(resolve_shorebird)"

require_initialized() {
  local app="$1"
  if [[ ! -f "$mobile_root/$app/shorebird.yaml" ]]; then
    printf '%s is not initialized. Run: scripts/shorebird_apps.sh init %s\n' "$app" "$app" >&2
    exit 1
  fi
}

requires_openai_key() {
  case "$1" in
    nx_cards|nx_docs) return 0 ;;
    *) return 1 ;;
  esac
}

require_openai_env() {
  local env_file="$mobile_root/nx_modules/nx_live_agent/.env"
  local api_key

  if [[ ! -f "$env_file" ]]; then
    printf 'Missing OpenAI build configuration: %s\n' "$env_file" >&2
    exit 1
  fi

  api_key="$(awk '
    /^[[:space:]]*OPENAI_API_KEY[[:space:]]*=/ {
      value = $0
      sub(/^[^=]*=[[:space:]]*/, "", value)
      sub(/[[:space:]]*$/, "", value)
      print value
      exit
    }
  ' "$env_file")"

  case "$api_key" in
    ''|'""'|"''"|'PASTE_OPENAI_API_KEY_HERE')
      printf 'OPENAI_API_KEY is missing or empty in %s\n' "$env_file" >&2
      exit 1
      ;;
  esac
}

add_shorebird_asset() {
  local pubspec="$1"
  local insertion_line
  local temp_file

  if grep -Eq '^[[:space:]]*-[[:space:]]+shorebird\.yaml[[:space:]]*$' "$pubspec"; then
    return
  fi

  insertion_line="$(awk '
    /^flutter:[[:space:]]*$/ { in_flutter = 1; next }
    in_flutter && /^[^[:space:]#]/ { exit }
    in_flutter && /^  assets:[[:space:]]*$/ { print NR; exit }
  ' "$pubspec")"

  if [[ -z "$insertion_line" ]]; then
    insertion_line="$(awk '/^flutter:[[:space:]]*$/ { print NR; exit }' "$pubspec")"
    [[ -n "$insertion_line" ]] || {
      printf 'Could not find the Flutter section in %s\n' "$pubspec" >&2
      exit 1
    }
    temp_file="$(mktemp "${TMPDIR:-/tmp}/shorebird-pubspec.XXXXXX")"
    awk -v line="$insertion_line" '
      { print }
      NR == line { print "  assets:"; print "    - shorebird.yaml" }
    ' "$pubspec" > "$temp_file"
  else
    temp_file="$(mktemp "${TMPDIR:-/tmp}/shorebird-pubspec.XXXXXX")"
    awk -v line="$insertion_line" '
      { print }
      NR == line { print "    - shorebird.yaml" }
    ' "$pubspec" > "$temp_file"
  fi

  mv "$temp_file" "$pubspec"
}

initialize_app() {
  local app="$1"
  local app_dir="$mobile_root/$app"
  local display_name
  local temp_root
  local org_args=()

  require_app "$app"
  if [[ -f "$app_dir/shorebird.yaml" ]]; then
    printf '%s is already initialized.\n' "$app"
    return
  fi

  display_name="$(display_name_for "$app")"
  temp_root="$(mktemp -d "${TMPDIR:-/tmp}/nexus-shorebird-${app}.XXXXXX")"

  # Shorebird inspects every platform during init. Copy only the iOS project so
  # iOS-only users do not need Java, Gradle, or an Android SDK.
  rsync -a \
    --exclude android \
    --exclude build \
    --exclude macos \
    --exclude web \
    --exclude .dart_tool \
    --exclude .git \
    "$app_dir/" "$temp_root/"

  if [[ -n "${SHOREBIRD_ORGANIZATION_ID:-}" ]]; then
    org_args=(--organization-id "$SHOREBIRD_ORGANIZATION_ID")
  fi

  (
    cd "$temp_root"
    "$shorebird_bin" init --display-name "$display_name" "${org_args[@]}"
  )

  cp "$temp_root/shorebird.yaml" "$app_dir/shorebird.yaml"
  add_shorebird_asset "$app_dir/pubspec.yaml"
  rm -rf "$temp_root"

  printf '%s initialized for iOS.\n' "$app"
}

changed_files() {
  local base_ref="${1:-HEAD}"
  git -C "$mobile_root" diff --name-only "$base_ref"
  git -C "$mobile_root" ls-files --others --exclude-standard
}

affected_apps() {
  local base_ref="${1:-HEAD}"
  local file
  local app
  local affected=()

  while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    case "$file" in
      nx_modules/nx_db/*)
        affected=("${apps[@]}")
        break
        ;;
      nx_modules/nx_views/*)
        affected+=(nx_main nx_time)
        ;;
      nx_modules/nx_voice/*)
        affected+=(nx_main nx_docs nx_time)
        ;;
      nx_modules/nx_observability/*)
        affected+=(nx_main nx_time)
        ;;
      nx_modules/nx_live_agent/*|nx_modules/nx_offline/*)
        affected+=(nx_cards nx_docs)
        ;;
      third_party/appflowy-editor/*)
        affected+=(nx_docs)
        ;;
      nx_books/*|nx_cards/*|nx_cooking/*|nx_docs/*|nx_expense/*|nx_main/*|nx_people/*|nx_post/*|nx_projects/*|nx_time/*)
        app="${file%%/*}"
        affected+=("$app")
        ;;
    esac
  done < <(changed_files "$base_ref")

  for app in "${apps[@]}"; do
    local candidate
    for candidate in "${affected[@]}"; do
      if [[ "$candidate" == "$app" ]]; then
        printf '%s\n' "$app"
        break
      fi
    done
  done
}

list_apps() {
  local app
  local state
  for app in "${apps[@]}"; do
    state='not initialized'
    [[ -f "$mobile_root/$app/shorebird.yaml" ]] && state='initialized'
    printf '%-14s %s\n' "$app" "$state"
  done
}

run_release() {
  local app="$1"
  local credential_args=()
  shift
  require_app "$app"
  require_initialized "$app"
  if requires_openai_key "$app"; then
    require_openai_env
    credential_args=(--dart-define-from-file=../nx_modules/nx_live_agent/.env)
  fi
  (
    cd "$mobile_root/$app"
    "$shorebird_bin" release ios "${credential_args[@]}" "$@"
  )
}

run_patch() {
  local app="$1"
  local credential_args=()
  shift
  require_app "$app"
  require_initialized "$app"
  if requires_openai_key "$app"; then
    require_openai_env
    credential_args=(--dart-define-from-file=../nx_modules/nx_live_agent/.env)
  fi
  (
    cd "$mobile_root/$app"
    "$shorebird_bin" patch ios "${credential_args[@]}" "$@"
  )
}

run_preview() {
  local app="$1"
  shift
  require_app "$app"
  require_initialized "$app"
  (
    cd "$mobile_root/$app"
    "$shorebird_bin" preview --platform ios "$@"
  )
}

command_name="${1:-}"
[[ -n "$command_name" ]] || {
  usage
  exit 2
}
shift

case "$command_name" in
  doctor)
    "$shorebird_bin" doctor
    ;;
  list)
    list_apps
    ;;
  init)
    target="${1:-}"
    [[ -n "$target" ]] || { usage >&2; exit 2; }
    if [[ "$target" == all ]]; then
      for app in "${apps[@]}"; do
        initialize_app "$app"
      done
    else
      initialize_app "$target"
    fi
    ;;
  release)
    app="${1:-}"
    [[ -n "$app" ]] || { usage >&2; exit 2; }
    shift
    run_release "$app" "$@"
    ;;
  patch)
    target="${1:-}"
    [[ -n "$target" ]] || { usage >&2; exit 2; }
    shift
    if [[ "$target" == changed ]]; then
      targets=()
      while IFS= read -r app; do
        [[ -n "$app" ]] && targets+=("$app")
      done < <(affected_apps HEAD)
      ((${#targets[@]} > 0)) || {
        printf 'No affected Nexus apps found.\n'
        exit 0
      }
      for app in "${targets[@]}"; do
        run_patch "$app" "$@"
      done
    else
      run_patch "$target" "$@"
    fi
    ;;
  preview)
    app="${1:-}"
    [[ -n "$app" ]] || { usage >&2; exit 2; }
    shift
    run_preview "$app" "$@"
    ;;
  affected)
    affected_apps "${1:-HEAD}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$command_name" >&2
    usage >&2
    exit 2
    ;;
esac
