#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Build and deploy Nexus Flutter web apps to nexus-server.

Usage:
  scripts/deploy_web_apps.sh [all|APP ...] [options]

Apps:
  nx_notes     aliases: notes, docs
  nx_books     aliases: books
  nx_expense   aliases: expense, expenses
  nx_people    aliases: people
  nx_projects  aliases: projects

Options:
  --skip-build        Sync the existing build/web output instead of rebuilding.
  --skip-pi          Only update the local server static mirror.
  --skip-container   Sync to the Pi checkout, but do not docker cp/restart.
  --skip-restart     Do not restart nexus-server after docker cp.
  --skip-verify      Do not curl the Pi origin after deploy.
  -h, --help         Show this help.

Environment overrides:
  NEXUS_SERVER_ROOT      Local server checkout. Default: ../servers
  NEXUS_PI_TARGET        SSH target. Default: nathik@10.0.0.156
  NEXUS_PI_SERVER_DIR    Pi server checkout. Default: /home/nathik/Nexus/nexus-server
  NEXUS_SERVER_CONTAINER Docker container. Default: nexus-server
  NEXUS_PI_ORIGIN        Pi HTTP origin. Default: http://10.0.0.156:8001
  NEXUS_PI_HOST_UID      Pi checkout owner uid. Default: 1000
  NEXUS_PI_HOST_GID      Pi checkout owner gid. Default: 1000
  FLUTTER_BIN            Flutter binary. Default: flutter
USAGE
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mobile_root="$(cd "$script_dir/.." && pwd)"
nexus_root="$(cd "$mobile_root/.." && pwd)"

server_root="${NEXUS_SERVER_ROOT:-$nexus_root/servers}"
local_static_root="$server_root/nexus/http/static"
pi_target="${NEXUS_PI_TARGET:-nathik@10.0.0.156}"
pi_server_dir="${NEXUS_PI_SERVER_DIR:-/home/nathik/Nexus/nexus-server}"
container_name="${NEXUS_SERVER_CONTAINER:-nexus-server}"
pi_origin="${NEXUS_PI_ORIGIN:-http://10.0.0.156:8001}"
pi_host_uid="${NEXUS_PI_HOST_UID:-1000}"
pi_host_gid="${NEXUS_PI_HOST_GID:-1000}"
flutter_bin="${FLUTTER_BIN:-flutter}"

skip_build=0
skip_pi=0
skip_container=0
skip_restart=0
skip_verify=0
requested_apps=()

app_order=(nx_notes nx_books nx_expense nx_people nx_projects)

base_href_for() {
  case "$1" in
    nx_notes) printf '/docs/' ;;
    nx_books) printf '/books/' ;;
    nx_expense) printf '/expenses/' ;;
    nx_people) printf '/people/' ;;
    nx_projects) printf '/projects/' ;;
    *) return 1 ;;
  esac
}

static_dir_for() {
  case "$1" in
    nx_notes|nx_books|nx_expense|nx_people|nx_projects) printf '%s' "$1" ;;
    *) return 1 ;;
  esac
}

normalize_app() {
  case "$1" in
    all) printf 'all' ;;
    nx_notes|notes|docs) printf 'nx_notes' ;;
    nx_books|books) printf 'nx_books' ;;
    nx_expense|expense|expenses) printf 'nx_expense' ;;
    nx_people|people) printf 'nx_people' ;;
    nx_projects|projects) printf 'nx_projects' ;;
    *)
      printf 'Unknown app: %s\n' "$1" >&2
      return 1
      ;;
  esac
}

while (($#)); do
  case "$1" in
    --skip-build) skip_build=1 ;;
    --skip-pi) skip_pi=1 ;;
    --skip-container) skip_container=1 ;;
    --skip-restart) skip_restart=1 ;;
    --skip-verify) skip_verify=1 ;;
    -h|--help)
      usage
      exit 0
      ;;
    --*)
      printf 'Unknown option: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
    *)
      requested_apps+=("$(normalize_app "$1")")
      ;;
  esac
  shift
done

if ((${#requested_apps[@]} == 0)); then
  requested_apps=(all)
fi

deploy_apps=()
for app in "${requested_apps[@]}"; do
  if [[ "$app" == all ]]; then
    deploy_apps=("${app_order[@]}")
    break
  fi
  deploy_apps+=("$app")
done

dedupe_apps=()
if ((${#deploy_apps[@]} > 0)); then
  for app in "${deploy_apps[@]}"; do
    seen=0
    if ((${#dedupe_apps[@]} > 0)); then
      for existing in "${dedupe_apps[@]}"; do
        if [[ "$existing" == "$app" ]]; then
          seen=1
          break
        fi
      done
    fi
    if ((seen == 0)); then
      dedupe_apps+=("$app")
    fi
  done
fi
deploy_apps=("${dedupe_apps[@]}")

require_dir() {
  if [[ ! -d "$1" ]]; then
    printf 'Required directory not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_dir "$mobile_root"
require_dir "$server_root"
mkdir -p "$local_static_root"

for cmd in rsync perl curl grep; do
  command -v "$cmd" >/dev/null || {
    printf 'Required command not found: %s\n' "$cmd" >&2
    exit 1
  }
done

if ((skip_build == 0)); then
  command -v "$flutter_bin" >/dev/null || {
    printf 'Flutter command not found: %s\n' "$flutter_bin" >&2
    exit 1
  }
fi

if ((skip_pi == 0)); then
  command -v ssh >/dev/null || {
    printf 'Required command not found: ssh\n' >&2
    exit 1
  }
fi

cache_bust() {
  local build_dir="$1"
  local version="$2"
  local index_file="$build_dir/index.html"
  local bootstrap_file="$build_dir/flutter_bootstrap.js"

  if [[ -f "$index_file" ]]; then
    perl -0pi -e "s#<script src=\"flutter_bootstrap\\.js(?:\\?v=[0-9]+)?\" async></script>#<script src=\"flutter_bootstrap.js?v=$version\" async></script>#" "$index_file"
  fi

  if [[ -f "$bootstrap_file" ]]; then
    perl -0pi -e "s#\"mainJsPath\":\"main\\.dart\\.js(?:\\?v=[0-9]+)?\"#\"mainJsPath\":\"main.dart.js?v=$version\"#" "$bootstrap_file"
  fi

  printf '%s\n' "$version" > "$build_dir/.deploy_version"
}

build_app() {
  local app="$1"
  local base_href="$2"
  local version="$3"
  local app_dir="$mobile_root/$app"
  require_dir "$app_dir"

  if ((skip_build == 0)); then
    printf '\n==> Building %s with base href %s\n' "$app" "$base_href" >&2
    (
      cd "$app_dir"
      "$flutter_bin" pub get
      "$flutter_bin" build web --release --base-href "$base_href"
    )
  else
    printf '\n==> Reusing existing build/web for %s\n' "$app" >&2
  fi

  require_dir "$app_dir/build/web"
  cache_bust "$app_dir/build/web" "$version"
  chmod -R a+rX "$app_dir/build/web"
}

sync_local() {
  local app="$1"
  local static_dir="$2"
  local app_dir="$mobile_root/$app"
  local target_dir="$local_static_root/$static_dir"

  printf '==> Syncing %s to local static mirror %s\n' "$app" "$target_dir"
  mkdir -p "$target_dir"
  rsync -az --delete --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
    "$app_dir/build/web/" \
    "$target_dir/"
}

sync_pi() {
  local app="$1"
  local static_dir="$2"
  local app_dir="$mobile_root/$app"
  local remote_dir="$pi_server_dir/nexus/http/static/$static_dir"

  printf '==> Syncing %s to %s:%s\n' "$app" "$pi_target" "$remote_dir"
  ssh "$pi_target" "mkdir -p '$remote_dir'"
  if ((skip_container == 0)); then
    ssh "$pi_target" "\
      docker exec -u root '$container_name' sh -lc 'if [ -d /app/nexus/http/static/$static_dir ]; then chown -R $pi_host_uid:$pi_host_gid /app/nexus/http/static/$static_dir || true; fi'\
    "
  fi
  rsync -az --delete --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r \
    "$app_dir/build/web/" \
    "$pi_target:$remote_dir/"

  if ((skip_container == 0)); then
    if ssh "$pi_target" "\
      docker inspect '$container_name' --format '{{range .Mounts}}{{println .Destination}}{{end}}' \
        | grep -qx '/app/nexus'\
    "; then
      printf '==> Container has /app/nexus bind-mounted; docker cp is not needed for %s\n' "$app"
      ssh "$pi_target" "\
        docker exec -u root '$container_name' sh -lc 'chmod -R a+rX /app/nexus/http/static/$static_dir'\
      "
    else
      printf '==> Copying %s into container %s\n' "$app" "$container_name"
      ssh "$pi_target" "\
        set -e; \
        docker exec -u root '$container_name' sh -lc 'mkdir -p /app/nexus/http/static/$static_dir'; \
        docker cp '$remote_dir/.' '$container_name:/app/nexus/http/static/$static_dir/'; \
        docker exec -u root '$container_name' sh -lc 'chown -R $pi_host_uid:$pi_host_gid /app/nexus/http/static/$static_dir && chmod -R a+rX /app/nexus/http/static/$static_dir'\
      "
    fi
  fi
}

verify_app() {
  local app="$1"
  local base_href="$2"
  local version="$3"
  local url="${pi_origin%/}${base_href}"
  local tmp_dir="${TMPDIR:-/tmp}/nexus-web-deploy"
  local attempt

  mkdir -p "$tmp_dir"
  printf '==> Verifying %s at %s\n' "$app" "$url"
  for attempt in $(seq 1 60); do
    if curl -fsS -D "$tmp_dir/$app.headers" "$url" -o "$tmp_dir/$app.index.html" 2>"$tmp_dir/$app.curl.err" \
      && grep -q "flutter_bootstrap.js?v=$version" "$tmp_dir/$app.index.html" \
      && curl -fsS "${url}main.dart.js?v=$version" -o "$tmp_dir/$app.main.dart.js" 2>>"$tmp_dir/$app.curl.err"; then
      break
    fi
    if [[ "$attempt" == 60 ]]; then
      printf 'Verification failed for %s after %s attempts.\n' "$app" "$attempt" >&2
      cat "$tmp_dir/$app.curl.err" >&2
      return 1
    fi
    sleep 1
  done
  printf '    ok: version=%s bytes=%s\n' "$version" "$(wc -c < "$tmp_dir/$app.main.dart.js" | tr -d ' ')"
}

versions=()
for app in "${deploy_apps[@]}"; do
  base_href="$(base_href_for "$app")"
  static_dir="$(static_dir_for "$app")"
  version="$(date +%s)"
  build_app "$app" "$base_href" "$version"
  versions+=("$app:$version:$base_href")
  sync_local "$app" "$static_dir"
  if ((skip_pi == 0)); then
    sync_pi "$app" "$static_dir"
  fi
done

if ((skip_pi == 0 && skip_container == 0 && skip_restart == 0)); then
  printf '\n==> Restarting %s on %s\n' "$container_name" "$pi_target"
  ssh "$pi_target" "docker restart '$container_name' >/dev/null && docker ps --filter name='^/$container_name$' --format '{{.Names}} {{.Status}}'"
fi

if ((skip_pi == 0 && skip_verify == 0)); then
  for item in "${versions[@]}"; do
    IFS=: read -r app version base_href <<<"$item"
    verify_app "$app" "$base_href" "$version"
  done
fi

printf '\nDeployed:'
for item in "${versions[@]}"; do
  IFS=: read -r app version _ <<<"$item"
  printf ' %s@%s' "$app" "$version"
done
printf '\n'
