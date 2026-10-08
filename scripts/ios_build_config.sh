# Shared compile-time configuration for direct and Shorebird iOS builds.
# Caller sets mobile_root before sourcing. Never print credential values.
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

